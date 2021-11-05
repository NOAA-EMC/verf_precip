#!/bin/ksh 
###############################################################################
# Name of Script: exverf_precip_verfgen_24h.sh.sms
# Purpose of Script: To generate the 24h (12Z-12Z) precipitation Fractions
#   Skill Scores statistics for various operational models to be used by the
#   Forecast Verification System
# Arguments: exverf_precip_fss_24h.sh.sms $yyyy$mm$dd
# Log history: 
#    2009-05-22 Creation of script
#    2013-09-23 Modified for WCOSS; use 12Z-12Z CCPA
###############################################################################
set -x

vyear=`echo $vday | cut -c 1-4`

# export vacc so fss.f knows whether this is 24h or 06h verif (for thresholds, 
# VSDB records):
export vacc=24

ccpafile=ccpa.${vday}12.24h
cp $COMIN.${vday}/$ccpafile .

err=$?
if [ $err -ne 0 ]; then
  echo $ccpafile not available.  EXIT FSS job for $vday
  exit
fi

cp $FIXverf_precip/stage3_mask.grb .
mkdir vsdb

vgrid=240

domainparm=verf_precip_fss_24h.domains
cp $PARMverf_precip/$domainparm .

echo 'Use config file to select domains entries that are used in this job.'

if [ -s fss.domains ]; then rm -f fss.domains; fi

cat $domainparm |while read tmp
do
  first_char=`echo $tmp |cut -c1`
  if [ ! "$first_char" = "#" ]   # Skip comment line
  then
    modnam=`echo $tmp |awk -F"|" '{print $1}'`
    let "runmod=run_$modnam"
    if [ $runmod = 1 ]; then echo $tmp >> fss.domains; fi
  fi
done

# fss.domains contains only the domain info for models being verified 
# in this run.  
cat fss.domains |while read tmp
do
  modnam_m1=${modnam:-none}
  modnam=`echo $tmp |awk -F"|" '{print $1}'`
  cycs=`echo $tmp |awk -F"|" '{print $2}'`
  fcsthour=`echo $tmp |awk -F"|" '{print $3}'`
  nests=`echo $tmp |awk -F"|" '{print $4}'`

  if ! [ -d $COMVSDB/$modnam ]; then
    mkdir -p $COMVSDB/$modnam
  fi

  if [ $modnam != $modnam_m1 ]
  then
    if [ -s $COMVSDB/$modnam/${modnam}_${vday}.vsdb ]
    then
      sed -e "/FSS<.*APCP\/24/d" $COMVSDB/$modnam/${modnam}_${vday}.vsdb >$COMVSDB/$modnam/${modnam}_${vday}.vsdb1
      mv $COMVSDB/$modnam/${modnam}_${vday}.vsdb1 $COMVSDB/$modnam/${modnam}_${vday}.vsdb
    fi
  fi
#
# Arguments for verf_precip_verf24.sh:
#  1. Model name
#  2. Verification date/hour
#  3. Verification grid
#  4: model cycles
#  5: range of model forecast to be verified.  This is not necessarily the 
#       limit of the model forecast length - e.g. forecast might be out to
#       10 days but only verified for 84 hours, then this number should
#       be '84'.  If this number is '96' and the model has a 12Z cycle,
#       then 96h fcst will be verified.
#  6: special mask?  (nests)

  $USHverf_precip/verf_precip_fss24.sh $modnam $vgrid "$cycs" $fcsthour $nests
done
 
cd $DATA/vsdb

# tar up the VSDB files so job on tempest can fetch them.
#   only save the finished VSDB files - the ones ending with '.vsdb'.  The
#   intermediate vsdb components are named 'vsdb.$mod.$fhour.$vgrid', skip them.
tar cvf ../vsdbfss24.$vday.tar *.vsdb 

cd $DATA

if [ $SENDCOM = YES ]
then
  cp vsdbfss24.$vday.tar ${COMOUT}.${vday}/. 

  if [ $RUN_ENVIR = dev ]
  then
    if [ ! -d $ARCH45DAY ]; then mkdir -p $ARCH45DAY; fi
    cp vsdbfss24.$vday.tar $ARCH45DAY/.
  fi
fi
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
