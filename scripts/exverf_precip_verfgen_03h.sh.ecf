#!/bin/ksh
################################################################################
# Name of Script: exverf_precip_verfgen_03h.sh.sms
# Purpose of Script: Performs the 03h precipitation verification
#   (00/03/06/09/12/15/18/21) 
#   for $day, using Stage II analysis. The 'late' stage II run is made
#   18 hours later, so data for ${day}21 would be ready before ${dayp1}16.
#   We are running this job in the early morning each $day, for ${daym2}
# Log history:
################################################################################
set -x

cd $DATA

#############################
# Copy the mask files over:
#############################
cp $FIXverf_precip/verf_precip_regmask_211.Z regmask_211.Z
cp $FIXverf_precip/verf_precip_regmask_212.Z regmask_212.Z
cp $FIXverf_precip/verf_precip_regmask_218.Z regmask_218.Z

gunzip *mask*

# Analysis type in vsdb file is 'CCPA' (i.e. 3-hourly CCPA):
export VERFANL=CCPA

#################################################################
# get CCPA 3-hourly precip data covering 21Z $vdaym1 - 21Z $vday.
# Rename the file to ccpa.${vdate}.03h, where $vdate is the ending 
# time of the 3-hourly accumulation period. 
#################################################################
vdayp1=`date -d "$vday + 1 day" +%Y%m%d`

cp $COMCCPA.$vday/00/ccpa.t00z.03h.hrap.conus   ccpa.${vday}00.03h
cp $COMCCPA.$vday/06/ccpa.t03z.03h.hrap.conus   ccpa.${vday}03.03h
cp $COMCCPA.$vday/06/ccpa.t06z.03h.hrap.conus   ccpa.${vday}06.03h
cp $COMCCPA.$vday/12/ccpa.t09z.03h.hrap.conus   ccpa.${vday}09.03h
cp $COMCCPA.$vday/12/ccpa.t12z.03h.hrap.conus   ccpa.${vday}12.03h
cp $COMCCPA.$vday/18/ccpa.t15z.03h.hrap.conus   ccpa.${vday}15.03h
cp $COMCCPA.$vday/18/ccpa.t18z.03h.hrap.conus   ccpa.${vday}18.03h
cp $COMCCPA.$vdayp1/00/ccpa.t21z.03h.hrap.conus ccpa.${vday}21.03h

# save them on $COMOUT.$vday, in case there are questions later about the 
# quality of the ccpa 3-hourly at the time of verification (CCPAs are updated 
# out to 7-days)
cp ccpa.${vday}*.03h $COMOUT.${vday}/.

# map the CCPA to the verifying grid(s):

for grid in 218
do 
  for hh in 00 03 06 09 12 15 18 21
  do
    $COPYGB -g $grid -i3 -x ccpa.${vday}${hh}.03h ccpa.${vday}${hh}.03h.$grid
  done
done

#################################
# Run the verification  
#
# Arguments for verf_precip_verf3.sh:
#  1. Model name
#  2. Verification length
#  3: grids to be verified on
#  4: model cycles
#  5: bucket length
#  6: range of model forecast
#  7: optional altcomin for dev: get model QPF file from prod instead of
#       dev's verf.dat?
#################################
mkdir $DATA/vsdb

cp $PARMverf_precip/verf_precip_verf03.domains verf03.domains
cat verf03.domains |while read tmp
do
   first_char=`echo $tmp |cut -c1`
   if [ "$first_char" = "#" ]
   then
     echo "This is a comment line, skip it"
   else
     modnam_m1=${modnam:-none}
     modnam=`echo $tmp |awk -F"|" '{print $1}'`
     vlen=`echo $tmp |awk -F"|" '{print $2}'`
     grids=`echo $tmp |awk -F"|" '{print $3}`
     cycs=`echo $tmp |awk -F"|" '{print $4}'`
     blen=`echo $tmp |awk -F"|" '{print $5}'`
     fcsthour=`echo $tmp |awk -F"|" '{print $6}'`
     # the optional 8th argument in the parm input is 'altcomin', which is
     # used sometimes in dev mode, directing the script to look for model 
     # qpf in the prod directory (/com/verf/prod/precip.$day), rather than
     # in the regular dev verf.dat/precip.$day directory.  COMIN1 and COMIN2
     # is set in parm/verf_precip_config:
     #   export COMIN1=$DATAverf_precip/precip
     #   export COMIN2=/com/verf/prod/precip
     altopt=`echo $tmp |awk -F"|" '{print $7}'`
     # since altcomin is optional, 
     # the above altopt might be empty.  To avoid an error msg in the IF block
     # below, make it a character string of "null" if it does not have a 
     # pre-assigned value.
     altopt=${altopt:-null}
     if [ $altopt = altcomin ]; then
       export COMIN=$COMIN2
     else
       export COMIN=$COMIN1
     fi

#    Since 3-hourly and 24-hourly stats are kept in the same VSDB file, if we
#    make a re-run for the 3-hour, we need to remove the existing 3h stats
#    from the VSDB file and keep the 24h stats.  This is how it is done below:
#      1) Check to see that, within this job, this is the first time "modnam"
#         is being verified (models such as "NAM" might appear multiple times
#         in verf_precip_verfXX.domains, first to be verified over CoNUS, 
#         and again on special sub-regions).  
#      2) If VSDB file for this model/day already exists; if so, delete 
#         all lines containing the string APCP/03 from the VSDB file.
#
     let "runmod=run_$modnam"
     if [ $runmod = 1 ]
     then
       if [ $modnam != $modnam_m1 ]
       then
         if [ -s $COMVSDB/$modnam/${modnam}_${vday}.vsdb ]
         then
           sed -e "/APCP\/03/d" $COMVSDB/$modnam/${modnam}_${vday}.vsdb >$COMVSDB/$modnam/${modnam}_${vday}.vsdb1
           mv $COMVSDB/$modnam/${modnam}_${vday}.vsdb1 $COMVSDB/$modnam/${modnam}_${vday}.vsdb
         fi
       fi

       $USHverf_precip/verf_precip_verf03.sh $modnam $vday $vlen "$grids" "$cycs" $blen $fcsthour
    fi
  fi
done

cd vsdb
tar cvf ../vsdb3.$vday.tar .

cd $DATA

if [ $SENDCOM = YES ]
then
  cp vsdb3.$vday.tar ${COMOUT}.${vday}/.
 
  if [ $RUN_ENVIR = "dev" -a $LOGNAME = "Alicia.Bentley" ]
  then
    cp vsdb3.$vday.tar $ARCH45DAY/.
#   scp vsdb3.$vday.tar gcp@rzdm:/home/ftp/emc/mmb/gcp/precip/files/.
  fi
fi

###############################################################################
# For operational implementation: send the tar'd VSDBs to ftpprd.
###############################################################################
if [ $SENDDBN = YES ]
then
  $DBNROOT/bin/dbn_alert MODEL VERIF_PRECIP $job ${COMOUT}.${vday}/vsdb3.$vday.tar
fi

#####################################################################
# GOOD RUN
set +x
echo "**************$job COMPLETED NORMALLY on `date`"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
echo $msg
postmsg "$jlogfile" "$msg"

############## END OF SCRIPT #######################
