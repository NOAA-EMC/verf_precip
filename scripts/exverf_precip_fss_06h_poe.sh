#!/bin/ksh 
###############################################################################
# Name of Script: exverf_precip_verfgen_06h_poe.sh.sms
# Purpose of Script: To generate 06h precipitation Fractions
#   Skill Scores statistics for various operational models to be used by the
#   Forecast Verification System
# Arguments: exverf_precip_fss_06h_poe.sh.sms $vhr
#   Make FSS computations for 06h analysis (CCPA) ending at 00/06/12/18Z $vday
#   note that the 18Z analysis would be made/remade a day later than 00/06/12Z,
#   
# Log history: 
#    2015-06-29 Copied over from exverf_precip_fss_24h.sh
###############################################################################
set -x

vhr=$1

mkdir -p $DATA/$vhr/vsdb/parts
mkdir -p $DATA/$vhr/vsdb/subtotal.${vhr}z

cd $DATA/$vhr
# Run setup to initialize working directory and utility scripts
# JY setup.sh

cp $FIXverf_precip/stage3_mask.grb .

export vdate=${vday}${vhr}
# Fetch CCPA 6-hourly files:
ccpafile=$COMCCPA.$vday/$vhr/ccpa.t${vhr}z.06h.hrap.conus
cp $ccpafile ccpa.${vdate}.06h
err=$?
if [ $err -eq 0 ]; then
  cp ccpa.${vdate}.06h $COMOUT.$vday/.
else
  echo Error getting ccpa${cyc}, exist FSS06 for ${vdate}.
  exit
fi

# after the earlier prep, fss06.domains contains only the domain info for 
# models being verified in this run.  

cat $DATA/fss06.domains |while read tmp
do
  modnam=`echo $tmp |awk -F"|" '{print $1}'`
  cycs=`echo $tmp |awk -F"|" '{print $2}'`
  bucket=`echo $tmp |awk -F"|" '{print $3}'`
  frange=`echo $tmp |awk -F"|" '{print $4}'`
  altopt=`echo $tmp |awk -F"|" '{print $5}'`
  # the above altopt might be empty.  To avoid an error msg in the IF block
  # below, make it a character string of "null" if it does not have a 
  # pre-assigned value.
  # If altopt=altcomin, that means we are to search for the precip files of
  # the given model in /com/verf/prod/precip.$day instead of user directory,
  # $DATAverf_precip/precip.$day.  In parm/verf_precip_config, 
  #   COMIN1=$DATAverf_precip/precip
  #   COMIN2=/com/verf/prod/precip
  # this is in case we are running verif for model (e.g. NAM, GFS) whose
  # getppt is done in prod job.  
  altopt=${altopt:-null}
  if [ $altopt = altcomin ]; then
    export COMIN=$COMIN2
  else
    export COMIN=$COMIN1
  fi
#
# Arguments for verf_precip_verf06.sh ($vdate is exported)
#  1. Model name
#  2: model cycles
#  3: bucket length
#  4: range of model forecast to be verified.  This is not necessarily the 
#       limit of the model forecast length - e.g. forecast might be out to
#       10 days but only verified for 84 hours, then this number should
#       be '84'.  If this number is '96' and the model has a 12Z cycle,
#       then 96h fcst will be verified.

  $USHverf_precip/verf_precip_fss06.sh $modnam "$cycs" $bucket $frange
done
 
#####################################################################
# GOOD RUN
set +x
echo "**************$job COMPLETED NORMALLY on `date`"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
echo $msg
#yl postmsg "$jlogfile" "$msg"

############## END OF SCRIPT #######################
