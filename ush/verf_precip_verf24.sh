#!/bin/ksh

#############################################################################
# Name of script:    verf_precip_24h.sh
# Purpose of script: This script generate the 24h precipitation verification
#                    products
# Arguments for verf24.sh:
#  1. 'model' : Model name
#  2. 'vdate' : Verification date/hour
#  3. 'vacc'  : Verification length
#  4: 'grids' : grids to be verified on
#  5: 'cycles': model cycles
#  6: 'bucket': bucket length
#  7: 'frange': range of model forecast
#  8: 'nest'  : special mask?  (nest)
#############################################################################

set -x

cd $DATA

model=$1
export vdate=$2
export vacc=$3
grids=$4
cycles=$5
bucket=$6
frange=$7

# Build the model directory on the repository server (Currently CCS):
if [ ! -d $COMVSDB/$model ]; then
  mkdir -p $COMVSDB/$model
fi

if [ $# -eq 8 ]; then
  nest=$8
else
  nest=no
fi

# find the verification day (yyyymmdd):
vday=`echo $vdate | cut -c 1-8`

# export upper-case model name to verfgen (the model name in the vsdb
# file will be in upper case):

export MODNAM=`echo $model | tr "[a-z]" "[A-Z]"`

# Set the variable length, they are now all 3-digit:
# tdum - a temporary 3-digit number, used along with 'filevacc'
typeset -Z3 t0 t1 t2 tbgn tend tdum
# tbgnbkt is for when bucket > vacc (e.g. nssl4arw)
typeset -Z3 tbgnbkt

#############################################################################
#Step 1: Determine the initial forecast hour to reach the verification time:
#
# vacc : verification length (24h):
# fhour: forecast hour to reach verification time, e.g. the '60' in 
# the vsdb line 'V01 ETA 60 2002080112'.

# In the main loop, find the initial forecast hour ( fhour -ge 24h), 
# and increment it by fhrincr (forecast hour increment).

# Go through all cycles in the input "cycles" to determine the initial 
# forecast hour, which is the smallest number (-ge 24h) that will reach
# the verification time (12Z) for one of the cycles.  
# 
#     cycle       forecast hour
#      00            36
#      03            33
#      06            30
#      09            27
#      12            24
#      15            45
#      18            42
#      21            39
#
# i.e. for cyc -le 12, fhour=36-$cyc
#      for cyc -gt 12  fhour=24+$cyc
#
# First set fhour to a maximum value (should be < 48h), then go through
# all the cycles to find the smallest fhour:
#############################################################################

fhour=48

for cyc in $cycles
do
  if [ $cyc -le 12 ]; then
    let "fhr=36-$cyc"
  else
    let "fhr=60-$cyc"
  fi

  if [ $fhour -gt $fhr ]; then
    fhour=$fhr
  fi
done

# export fhour for verfgen24.f
export fhour

#############################################################################
#Step 2: Determine all the available files to be used in the verification
#
# This script was originally designed to increment forecast length
# by bucket length, with the assumption that bucket length would be
# shorter than the model cycle increments (Example 1: GFS has four
# cycles each day, so the 'cycle increment' is 6h, and the bucket
# length is 6h.  Example 2: NMMCENT is run once a day, so the 'cycle
# increment' is 24

# Increment for the main loop ('while') is the number of hours between
# two consecutive model cycles to be verified ('fhrincr').  For example,
# NMMCENT is verified once a day, so fhrincr=24.  Eta is verified
# four times a day ("00 06 12 18") so fhrincr=06.  
# Count the number of model cycles each day (e.g. "00 06 12 18" returns '4'):
#############################################################################
ncyc=`echo $cycles | wc -w`

if [ $ncyc -eq 1 ]; then
  fhrincr=24
else
  cyc1=`echo $cycles | gawk '{print $1}'`
  cyc2=`echo $cycles | gawk '{print $2}'`
  let "fhrincr=$cyc2-$cyc1"
fi


#############################################################################
# The following 'while' loop (increment: "fhour = $fhour + $bucket") 
# 
# Example 1: nam 2002080112 24 "190 211 212 218" "00 12" 12 84
#   fhrincr=12
#
#   Round 1: fhour=24
#            mdate=2002073112   ! forecast starting time (i.e. model cycle)
#            cyc=12             ! model cycle
#            day=20020731       ! this tells the script where to look for
#                                 the precip files:
#                                   nam_2002073112_000_012
#                                   nam_2002073112_012_024
#       sum up stuff:
#                t0=$fhour - $vacc = 24-24=000
#          file1:       t1=00
#                       t2=12
#                    file1=20020731/nam_2002073112_000_012
#          file2:       t1=12
#                       t2=24
#                    file2=20020731/nam_2002073112_012_024
#          file to be verified: nam_2002073112_000_024
#
#   Round 2: fhour=36
#            mdate=2002073100
#            cyc=00
#            day=20020731
#       sum up stuff:
#                t0=$fhour - $vacc = 36-24=012
#          file1:       t1=012
#                       t2=024
#                    file1=20020731/nam_2002073100_012_024
#          file2:       t1=24
#                       t2=36
#                    file2=20020731/nam_2002073100_024_036
#
#          file to be verified: nam_2002073100_012_036
#            
#   Round 3: fhour=48
#   Round 4: fhour=60
#   Round 5: fhour=72
#   Round 6: fhour=84
#   
# Example 2: nam 2002080112 24 "190 211 212 218" "06 18" 3 42
#   fhrincr=12
#
#   Round 1: fhour=30 (24+6)
#            mdate=2002073106
#            cyc=06
#            day=20020731
#       sum up stuff:
#                t0=$fhour - $vacc = 30-24=06
#                       t1=06
#                       t2=09
#                    file1=20020731/nam_2002073106_006_009
#                       t1=09
#                       t2=12
#                    file2=20020731/nam_2002073106_009_012
#                       t1=12
#                       t2=15
#                    file3=20020731/nam_2002073106_012_015
#                        .
#                        .
#                       t1=27
#                       t2=30
#                    file8=20020731/nam_2002073106_027_030
#
#              file to be verified: nam_2002073106_006_030
#
#   Round 2: fhour=42
#            mdate=2002073018
#            cyc=18
#  
#     accumulate:
#                    file1=20020730/nam_2002073018_018_021
#                    file2=20020730/nam_2002073018_021_024
#                        .
#                        .
#                    file8=20020730/nam_2002073018_039_042
#
#              file to be verified: nam_2002073018_018_042
#
#
#############################################################################
while [ $fhour -le $frange ]
do 
  mdate=`$NDATE -$fhour $vdate`  
  cyc=`echo $mdate | cut -c 9-10`
  day=`echo $mdate | cut -c 1-8`
# gather up model precip files needed to create the $vacc total (e.g. 24h:)
# Use 'AOK' to keep track whether all GRIB files needed to do the acc are 
# available.

# There are three scenarios: 
#   1) $bucket < $vacc: run nam_stage4_acc  (add) 
#   2) $bucket > $vacc: run verf_precip_diffpcp (subtract)
#   3) $bucket = $vacc: no need to do anything. 

# There is a 4th scenario, currently only applicable to nssl4arw's 12Z cycle: 
# the bucket does not get emptied, and we have
#   tbgnbkt = 24 - 36 (=-12)
# rather than fixing it, let's check to see if the desired 24h QPF file
# already exists on precip.yyyymmdd.  If so, copy over to work directory and
# skip all the adding/subtracting.  

# Use t0 for all three scenarios ( $bucket <, >, = $vacc) 
  let "t0 = $fhour - $vacc"
  let "tdum = $fhour" # so that the file below will have fhour in 3 digits:
  filevacc=${model}_${mdate}_${t0}_${tdum}
  if [ -s ${COMIN}.${day}/$filevacc ]; then
    cp ${COMIN}.${day}/$filevacc . # copy over the 24h QPF; go to verfgen now.
  elif [ $bucket -lt $vacc ]; then
    cat > input_acc << EOF
mod
${model}_
EOF

    AOK=YES 
    cat > input_acc << EOF
mod
${model}_
EOF

    # Sample worksheet: to get the 60h forecast of 24h precip valid at 
    # 2002070412, we need to sum up the following two files:
    #   nam_2002070200_036_048
    #   nam_2002070200_048_060
    #
    # format: nam_2002070400_024_036; ${model}_${T0}_$T1_$T2
    let "t1 = $t0"
    let "t2 = $t1 + $bucket"
  
    while [ $t2 -le $fhour ]; do
      onefile=${COMIN}.${day}/${model}_${mdate}_${t1}_${t2}
      if [ -s $onefile ]; then
        echo $onefile >> input_acc
        let "t1 = $t2"
        let "t2 = $t1 + $bucket"
      else
        echo $onefile is missing.
        AOK=NO
        break
      fi
    done

# Execute the program to calculate the accumulated precip:
    if [ $AOK = YES ]; then  # all model QPF files for this accum period exist
      pgm=nam_stage4_acc
      . prep_step
      msg="`date` -- $pgm for verf_24h started"
      postmsg "$jlogfile" "$msg"
      startmsg

      $EXECverf_precip/nam_stage4_acc < input_acc
      export err=$?; err_chk
    fi # end of "if [ $AOK = YES ]"
  # end of "if $bucket -lt $vacc"
  elif [ $bucket -gt $vacc ]; then       # BUCKET > VACC

    # Sample worksheet: wrf4nssl has a 36h bucket (actually the bucket is never
    # emptied, but it has a forecast range of 36h).  To ge the 36h forecast of
    # 24h precip valid at 2013030112, we need to subtract the amount in
    #   nssl4arw_2013022800_000_012
    # from 
    #   nssl4arw_2013022800_000_036
    # output file "modfile" from nam_stage4_acc need to have the 3-digit hour:
  
    if [ $fhour -ge $bucket ]; then
      let "tbgnbkt = $fhour - $bucket"
    else
      let "tbgnbkt = 0"
    fi

    let "t1 = $fhour - $vacc"
    let "t2 = $fhour"
    AOK=YES 
    cat > input_subtract <<EOF
mod
${model}_
EOF

    file1=${COMIN}.${day}/${model}_${mdate}_${tbgnbkt}_${t1}
    file2=${COMIN}.${day}/${model}_${mdate}_${tbgnbkt}_${t2}

    if [[ -s $file1 && -s $file2 ]]; then
      cat >> input_subtract <<EOF
$file1
$file2
EOF
      # Execute the program to calculate the difference:
      pgm=verf_precip_diffpcp
      . prep_step
      msg="`date` -- $pgm for verf_24h started"
      postmsg "$jlogfile" "$msg"

      startmsg
      $EXECverf_precip/verf_precip_diffpcp < input_subtract
      export err=$?; err_chk
    fi    #  if both files exist for diffpcp.
  else    #  BUCKET = VACC
    # if we're here, that means bucket=vacc.  Copy over the model file (output
    # from getppt) directly.  fhour is not 'typeset -Z3', so copy it to 'tend'.
    tend=$fhour
    cp ${COMIN}.${day}/${model}_${mdate}_${t0}_${tend} .

  fi # end of the IF block determining whether we need to add or subtract to
     # get correct amount forecast precip.  

  # This is the model file (after proper summation/subtraction if needed) to be
  # compared to the analysis file.  Still need to map to verifying grid. 
  let "tbgn = $t0"
  let "tend = $fhour"
  modfile=${model}_${mdate}_${tbgn}_${tend}
  if [[ -e $modfile ]]; then
    if [ $domain = conus ]; then   # Save the ConUS 24h totals
      cp $modfile qpf24h.dir/.
    fi
    for grid in $grids ; do
      if [ $nest = no ]; then
        maskfile=regmask_$grid
      elif [ $nest = ask ]; then
        maskfile=akmask_$grid
      elif [ $nest = hwi ]; then
        maskfile=himask_$grid
      elif [ $nest = pur ]; then
        maskfile=prmask_$grid
      else
        echo 'Invalid nest option.  STOP.'
        export err=9; err_chk
        err_exit
      fi

      # Find out if $modfile is already on $grid.  If not, use copygb 
      # to map it to $grid:
      mgrid=`$USHverf_precip/verf_precip_wwgrib.pl $modfile | gawk '{print $2}'`
      if [ $mgrid -eq $grid ]; then
        cp $modfile $modfile.$grid
      else
        if [ $model = metfr ]; then
          $COPYGB -N $FIXverf_precip/copygb.namelist -g ${grid} -i3 -x $modfile $modfile.$grid
        else
          $COPYGB -g ${grid} -i3 -x $modfile $modfile.$grid
        fi
      fi

      vsdb1=vsdb.$model.$vacc.$fhour.$grid
      
      pgm=verf_precip_verfgen
      . prep_step
      msg="`date` -- $pgm for verf_24h started"
      postmsg "$jlogfile" "$msg"
      ln -sf $modfile.$grid                         fort.11
      ln -sf vanl24.${grid}.$vdate                  fort.12
      ln -sf $maskfile                              fort.13
      ln -sf $vsdb1                                 fort.51
      startmsg
      $EXECverf_precip/verf_precip_verfgen 
      export err=$?; err_chk

      cat $vsdb1 >> $COMVSDB/$model/${model}_${vday}.vsdb
      cat $vsdb1 >> $DATA/vsdb/${model}_${vday}.vsdb

      # Save the $modfile.$grid for precip plot:
      # cp $modfile.$grid ${COMOUT}.${vday}/.

    done # LOOPING THROUGH GRIDS
  fi # if the $vtime (e.g.24h) sum of model precip exists:

  let "fhour = $fhour + $fhrincr"  
done # LOOP THRU FCST HOURS

exit 0
