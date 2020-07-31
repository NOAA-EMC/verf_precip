#!/bin/ksh 

#############################################################################
# Name of script:    verf_precip_fss06h.sh
# Purpose of script: This script generate the 06h precipitation Fractional
#                    Skill Scores
# Arguments for this script:
#  1. 'model'    : Model name
#  2: 'cycs'     : model cycles
#  3: 'buckets'  : model cycles
#  4: 'frange'   : range of model forecast
#############################################################################
set -x

vhr=`echo $vdate | cut -c 9-10`
cd $DATA/$vhr

model=$1
cycs=$2
bucket=$3
frange=$4

# export upper-case model name to fss.f (the model name in the vsdb
# file will be in upper case):

export MODNAM=`echo $model | tr "[a-z]" "[A-Z]"`

# Set the variable length, they are now all 3-digit:
typeset -Z3 t0 t1 t2 tbgn tend fhour

#############################################################################
#Step 1: Determine the initial forecast hour to reach the verification time:
#
# vacc : verification length (06):
# fhour: forecast hour to reach verification time, e.g. the '60' in 
# the vsdb line 'V01 ETA 60 2002080112'.

## In the main loop, find the initial forecast hour ( fhour -ge 24h), 
## and increment it by fhrincr (forecast hour increment).

#
## Go through all cycles in the input "cycles" to determine the initial 
## forecast hour, which is the smallest number (-ge 24h) that will reach
## the verification time (12Z) for one of the cycles.  
#
# We are doing only one verif time (vdate) per 'POE component'.  So for each 
# model, we'll go start with 6hours ending at vdate, then 6hours ending at 
# vdate-6, finally at 6hours ending at vdate-frange+6.
#
# e.g. verif time: 2015063000
#                  
#  model cycle   fcst hour
#            (fhour-vacc to fhour)
#  2015062918      00-06  
#  2015062912      06-12
#  2015062906      12-18
#  2015062900      18-24
#  2015062818      24-30
#  2015062812      30-36
#
#############################################################################

fhour=$vacc

while [ $fhour -le $frange ]; 
do
  # find model cycle ($mdate) that, with a forecast hour of $fhour, would
  # have a 6-hourly accumulation ending at $vdate (this accumulation might
  # later have to be produced by adding/subtracting).  Note that this model
  # cycle might or might not be among those specified in $cycles.

  # hypothetical model starting date/cycle
  mdate=`$NDATE -$fhour $vdate`
  mday=`echo $mdate | cut -c 1-8`
  mcyc=`echo $mdate | cut -c 9-10`
  
  mcycfound=N
  for cyc in $cycs
  do
    if [ $cyc = $mcyc ]
    then
      mcycfound=Y
      break
    fi
  done

  if [ $mcycfound = N ]; then  
    # This hypothetical model cycle is not among those listed in the parm file.
    # Skip the rest of the 'while' loop and go to the next fhour.
    let fhour=$fhour+$vacc         
    continue                   
  else
    # if we're here, then this fhour does correspond to a model cycle listed
    # in the parm file.  Find out if model files needed for the computation
    # exist.

    # There are four scenarios: 
    #   1) $bucket < $vacc: run nam_stage4_acc  (add) 
    #   2) $frange > $bucket > $vacc: run verf_precip_diffpcp (subtract)
    #   3) $bucket = $vacc: no need to do anything. 
    #   4) $frange = $bucket (bucket never gets emptied): nssl4arw

    # file we want: $model_$mdate_${fhour-vacc}_$fhour
    let "tbgn = $fhour - $vacc"
    let "tend = $fhour" # so that the file below will have fhour in 3 digits:
    fcstacc=${model}_${mdate}_${tbgn}_${tend}

    AOK=YES
    if [ -s ${COMIN}.${mday}/$fcstacc ]; then
      cp ${COMIN}.${mday}/$fcstacc . # copy over the 6h QPF; go to fss.f now
      err=$?
      if [ $err -ne 0 ]; then AOK=NO; fi
    elif [ $bucket -lt $vacc ]; then
      cat > input_acc << EOF
mod
${model}_
EOF
      let "t1 = $tbgn"
      let "t2 = $t1 + $bucket"
      while [ $t2 -le $fhour ]; do
        onefile=${COMIN}.${mday}/${model}_${mdate}_${t1}_${t2}
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

      if [ $AOK = YES ]; then
        startmsg
        $EXECverf_precip/nam_stage4_acc < input_acc
        export err=$?; err_chk
      fi
    elif [ $bucket -gt $vacc ]; then       # BUCKET > VACC
      # Example 1: NSSL4ARW has a never-emptying bucket (in addition to hrly):
      #   nssl4arw_2015063012_000_036
      #   nssl4arw_2015063012_000_030
      # Example 2: NAM 00/12h cycles have a 12h bucket
      #   nam_2015063012_024_036    
      #   nam_2015063012_024_030 (subtract this from above)
      #
      # we want model_2015063012_030_036  (model_$mdate_t1_t2)
      # input_subtract:
      #   mod
      #   model_
      #   model_$mdate_t0_t2
      #   model_$mdate_t0_t1
      # t2 is fhour.  Need to determine t0 and t1.
      #   t1=t2-vacc
      #   t0 is the multiple of bucket that is closest to t1 (but < t1)
      # t1/bucket returns an integer (the amount trailing the 'decimal point'
      #   is discarded.  E.g. 33/12 returns 2.  
      let "t2=fhour"
      let "t1=fhour-vacc"
      let t0="(t1/bucket)*bucket"
      file1=${COMIN}.${mday}/${model}_${mdate}_${t0}_${t1}
      file2=${COMIN}.${mday}/${model}_${mdate}_${t0}_${t2}
      if [[ -s $file1 && -s $file2 ]]; then 
        cat > input_subtract << EOF
mod
${model}_
$file1
$file2
EOF
        startmsg
        $EXECverf_precip/verf_precip_diffpcp < input_subtract
        export err=$?; err_chk
      else
        echo $file1 or $file2 non-existent 
      fi
    fi  # already have the 6h QPF, or need to add/subtract?
  fi    # model cycle exist for this forecast hour (per the parm domains)?

  export fhour   # export fhour for fss.f for the VSDBs

  if [ -s $fcstacc ]; then  # 6-hourly forecast file exist (either already
                            # in verf.dat/precip.$yyyymmdd, or through 
                            # add/subtract above
    if [ $vgrid -eq 240 ]; then
      gridhrap="255 5 1121 881 23117 -119023 8 -105000 4763 4763 0 64"
      $COPYGB -g "$gridhrap" -i3 -x $fcstacc $fcstacc.g240
    else
      echo Verification grid is not G240.  STOP. 
    fi

    vsdb1=vsdb.$model.f${fhour}h.v${vhr}z

    pgm=verf_precip_fss
    . prep_step
    msg="`date` -- $pgm for fss_24h started"
    postmsg "$jlogfile" "$msg"

# This is so we can tell from the screen which node the job is currently 
# running on: 
    hostname

    ln -sf $fcstacc.g240           fort.11
    ln -sf ccpa.$vdate.06h         fort.12
    ln -sf stage3_mask.grb         fort.13
    ln -sf vsdb/parts/$vsdb1       fort.51
      
    startmsg
    $EXECverf_precip/verf_precip_fss
    export err=$?; err_chk

    cat vsdb/parts/$vsdb1 >> vsdb/subtotal.${vhr}z/${model}_${vday}.vsdb

  fi # if the $vacc (e.g.06h) sum of model precip exists:

  let "fhour = $fhour + $vacc"  
done

exit 0
