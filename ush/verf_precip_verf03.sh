#!/bin/ksh

#############################################################################
# Name of script:    verf_precip_3h.sh
# Purpose of script: This script generate the 3 precipitation verification
#                    products
# Arguments for verf3.sh:
#  1. 'model' : Model name
#  2. 'vday'  : Verification day (multiple hours, e.g. 00,03,...18,21Z)
#  3. 'vacc'  : Verification length
#  4: 'grids' : grids to be verified on
#  5: 'cycles': model cycles
#  6: 'bucket': bucket length
#  7: 'frange': range of model forecast
#  8: 'nest'  : special mask?  (nests)
#############################################################################
set -x

model=$1
export vday=$2
export vacc=$3
grids=$4
cycles=$5
bucket=$6
frange=$7

cd $DATA

typeset -Z2 cyc
typeset -Z3 fhour0 fhourm3 fhourm2 fhourm1

export fhour vdate

if [ $# -eq 8 ]; then
  nest=$8
else
  nest=no
fi

if [ ! -d $COMVSDB/$model ]; then
  mkdir $COMVSDB/$model
fi

# export upper-case model name to verfgen (the model name in the vsdb
# file will be in upper case):
export MODNAM=`echo $model | tr "[a-z]" "[A-Z]"`

# loop structure: 
# Loop 1: The 8 verf times for the day, e.g., 2002100300/03/06/09/12/15/18/21
#   Loop 2: fhour=03,06,09,...,84 (flength)
#     cycle=vdate-fhour
#     if the last digit of 'cycle' is found in "cychrs", verify.
#     e.g. for vdate=2002100309, cychrs="00 12": skip fhour=03,06.  When 
#     fhour=09, cycle=2002100300, we verify:
#             nam_2002100300_06-09
#          How to get the 3-hour accumulations when the bucket length
#          is 12 hours:
#             nam_2002100300_06-09 = nam_2002100300_00-09 - 00-06
#
#     Loop 3: all grids to be verified on.
#
# For verif time of (e.g.) 2002100309, find out which model cycles/forecast
# hours we will be verifying.  For each cycle, do the following (use the
# 00Z cycle as an example):
#    
#  
# e.g.
# eta 2002100309 3 "212 218" "00 12" 12 84

# vacc : verification length (3h):
# fhour: forecast hour to reach verification time, e.g. the '60' in 
# the vsdb line 'V01 ETA 60 2002100309'.

# 
# The following 'while' loop (increment: "fhour = $fhour + $bucket") 
# 

for hh in 00 03 06 09 12 15 18 21
do                                            #  Loop Level 1
  # vdate exported for verfgen.x (outputted in vsdb file)
  export vdate=${vday}${hh}

  export fhour=$vacc  # possible model forecast hour: initialize with '03':

  while [ $fhour -le $frange ]; do            #  Loop Level 2
    mdate=`$NDATE -$fhour $vdate`  
    cyc=`echo $mdate | cut -c 9-10`
    day=`echo $mdate | cut -c 1-8`

    # Find out whether the beginning time coincide with a valid model cycle.  If
    # not, go on to the next forecast length:
    cycexist=`echo $cycles | grep $cyc | wc -l`
    if [ $cycexist -eq 0 ]; then
      let "fhour = $fhour + $vacc"
      continue
    fi
# 
# Now that we have found a valid forecast hour for the given verification 
# time.  The precip file we want is
#     $model_$mdate_($fhour-3)_$fhour
# For example if vdate=2002100309, cyc=00, fhour=09, we are looking for
#     nam_2002100300_006_009
# For the NAM 00Z cycle, the bucket length is 12h, so nam_2002100300_00_03
# would be in the archive but nam_2002100300_06_09 would not be.  For each
# 3h precip file we want, first check whether it is in the archive, if so,
# copy over.  Otherwise look for the precip accum for this cycle ending at
# $fhour, then look for the one ending at $fhourm3.  Copy them over and
# do the subtraction (assuming bucketlength > 3h)
#
# If the 3-hourly file we need is not in the precip.yyyymmdd archive, we
# will do a subtraction if bucket length > 3h, and addition if 
# bucket length = 1h (as in the new hrrrx parallel as of Oct 2017 - we are
# getting the hourly bucket rather than the never-emptied bucket, because
# the 0-24h sum has "0-1 day" in the wgrib2 inventory, too tricky to deal with)
# 
# for simplicity's sake we only consider bucketlength=1h, if it's < 3h.
#
    let "fhourm3 = $fhour - 3"  
    let "fhour0 = $fhour"
    modfile=${model}_${mdate}_${fhourm3}_${fhour0}

    if [ -e ${COMIN}.${day}/$modfile ]; then
      cp ${COMIN}.${day}/$modfile .
    else
      if [ $bucket -gt 3 ]; then
        tmpfilem3=${COMIN}.${day}/${model}_${mdate}_*_${fhourm3}
        tmpfile=${COMIN}.${day}/${model}_${mdate}_*_${fhour0}

        cat > input_subtract << EOF
mod
${model}_
EOF
        ntmpf=`ls -1 $tmpfilem3 $tmpfile | tee -a input_subtract | wc -l`
        if [ $ntmpf -eq 2 ]; then
          export pgm=verf_precip_diffpcp
          . prep_step

          $EXECverf_precip/verf_precip_diffpcp < input_subtract
          export err=$?; err_chk
        else
          echo Number of files to diff for \
            ${model}_${mdate}_${fhourm3}_${fhour0} is ${ntmpf}.  
        fi
      elif [ $bucket -eq 1 ]; then
        AOK=YES
        let "fhourm2 = $fhour0 - 2"  
        let "fhourm1 = $fhour0 - 1"  
        cat > input_acc <<EOF
mod
${model}_
EOF
        for onefile in ${model}_${mdate}_${fhourm3}_${fhourm2} \
                       ${model}_${mdate}_${fhourm2}_${fhourm1} \
                       ${model}_${mdate}_${fhourm1}_${fhour0}
        do 
          if [ -s ${COMIN}.${day}/$onefile ]; then
            echo ${COMIN}.${day}/$onefile >> input_acc
          else
            AOK=NO
            break
          fi
        done

        if [ $AOK = YES ]; then  # all three hourly QPFs exist
          export pgm=nam_stage4_acc
          . prep_step
          msg="`date` -- $pgm for verf_03h started"
          postmsg "$jlogfile" "$msg"
          startmsg
          $EXECverf_precip/nam_stage4_acc < input_acc
          export err=$?; err_chk
        fi
      else 
        echo Bucket length $bucket is less than 3h but not 1h!
      fi # bucket > 3 or =1? 
    fi # end getting 3-hourly file

    if [[ -e $modfile ]]; then
      for grid in $grids ; do
        if [ $nest = no ]; then
          maskfile=regmask_$grid
        elif [ $nest = west ]; then
          maskfile=westmask_$grid
        elif [ $nest = east ]; then
          maskfile=eastmask_$grid
        else
          echo 'Invalid nest option.  STOP.'
          exit
        fi # end assigning masks

        $COPYGB -g ${grid} -i3 -x $modfile $modfile.$grid

        if [ $fhour -lt 10 ]; then fhour=0$fhour; fi

        vsdb1=vsdb.$model.$vacc.$fhour.$grid
    
        pgm=verf_verfgen
        . prep_step
        msg="`date`  -- $pgm started "
        postmsg "$jlogfile" "$msg"

        ln -sf $modfile.$grid                   fort.11
        ln -sf ccpa.$vdate.03h.$grid            fort.12
        ln -sf $maskfile                        fort.13
        ln -sf $vsdb1                           fort.51
  
        startmsg
        $EXECverf_precip/verf_precip_verfgen
        export err=$?; err_chk;

        cat $vsdb1 >> vsdb/${model}_${vday}.vsdb
        
        if [ $SENDCOM = YES ]
        then
           cat $vsdb1 >>$COMVSDB/$model/${model}_${vday}.vsdb
        fi
      done # looping through grids
    fi # if the $vdate (e.g.24h) sum of model precip exists:
#
    let "fhour = $fhour + $vacc"  
  done # go to the next forecast length (started at 3h, increment by 3h,
       #    stop when the forecast length reaches max forecast range)
done   # go to the next verification hour (looping through 00,03,06,...,18,21Z
       #    in the day)

###############################################################################
# For operational implementation: send the VSDBs to ftpprd.
###############################################################################
#if [ $SENDDBN = YES ]
#then
#   $DBNROOT/bin/dbn_alert MODEL VERIF_PRECIP $job $COMVSDB/${model}/${model}_${vday}.vsdb
#fi

exit 0
