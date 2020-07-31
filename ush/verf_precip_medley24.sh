#!/bin/ksh
######################################################################## 
# Name of Script: medley24.sh
# Purpose of Script: Compute 24h and 48h precipitation forecast scores
# from the average of 8 operational models:
# 
#  1. NAM
#  2. GFS
#  3. CMC
#  4. CMCGLB
#  5. DWD
#  6. ECMWF
#  7. JMA
#  8. UKMO
#
# Verification grid is G212.  Use the models' 24h totals, mapped to G212, 
# produced from verf24.sh.
# 
# Usage: medley24.sh $vdate
# History:
######################################################################## 
set -x

cd $DATA

if [ $# -lt 1 ]
then
    echo "Invalid Argument"
    echo "Usage: medley24.sh yyyymmdd"
    err_exit
fi

export vdate=$1
export vacc=24
vday=`echo $vdate | cut -c 1-8`
yyyymm=`echo $vday | cut -c 1-6`
vdaym1=`date -d "$vday - 1 day" +%Y%m%d`

logfile=${COMOUT}.${vday}/medley_log.$vday
typeset -Z2 fhour

mkdir -p $COMVSDB/medley

models="nam gfs cmc cmcglb dwd ecmwf jma ukmo"

echo $vday > $logfile

for vtime in 000_024 024_048
do
  echo ' ' >> $logfile
  echo 'Missing model(s), for forecast length ' $vtime ' ' >> $logfile
  
# determine starting time of forecast.
  export fhour=`echo $vtime |awk -F"_" '{print $2}'` 
  sdate=`$NDATE -${fhour} $vdate`
  echo medley_${sdate}_${vtime}.212 > input_avg$fhour
  for model in $models
  do
    file=${model}_${sdate}_${vtime}.212
    if [ -s $file ]; then
      echo $file >> input_avg$fhour
    else
      echo ' ' $model >> $logfile
    fi
  done

  export pgm=verf_precip_average
  . prep_step

  msg="`date`  -- $pgm started "
  postmsg "$jlogfile" "$msg"

  startmsg
  $EXECverf_precip/verf_precip_average < input_avg$fhour 
  export err=$?; err_chk

  pgm=verf_precip_verfgen
  . prep_step
  msg="`date`  -- $pgm started "
  postmsg "$jlogfile" "$msg"

  export MODNAM=MEDLEY
  vsdb1=vsdb.medley.$fhour.${vtime}
  ln -sf medley_${sdate}_${vtime}.212     fort.11
  ln -sf vanl24.212.$vdate                fort.12
  ln -sf regmask_212                      fort.13
  ln -sf $vsdb1                           fort.51

  startmsg
  $EXECverf_precip/verf_precip_verfgen >>$pgmout
  export err=$?; err_chk

  cat $vsdb1 >> vsdb/medley_${vday}.vsdb
  cat $vsdb1 >> $COMVSDB/medley/medley_${vday}.vsdb

done

# save the medley precip files:
if [ $SENDCOM = YES ]
then
   cp medley_* ${COMOUT}.${vday}/.
fi

###############################################################################
# For operational implementation: send the VSDBs to ftpprd.
###############################################################################
#if [ $SENDDBN = YES ]
#then
#   $DBNROOT/bin/dbn_alert MODEL VERIF_PRECIP $job $COMVSDB/medley/medley_${vday}.vsdb
#fi

exit
