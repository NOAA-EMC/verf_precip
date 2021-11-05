#!/bin/ksh 
###############################################################################
# Name of Script: exverf_precip_verfgen_06h.sh.sms
# Purpose of Script: To generate 06h precipitation Fractions
#   Skill Scores statistics for various operational models to be used by the
#   Forecast Verification System
# Arguments: exverf_precip_fss_06h.sh.sms $yyyy$mm$dd ($vday)
#   Make FSS computations for 06h analysis (CCPA) ending at 00/06/12/18Z $vday
#   note that the 18Z analysis would be made/remade a day later than 00/06/12Z,
# Called by jobs/JVERF_PRECIP_FSS_06H
#   1) make a list of fss06 domain parm files that contain only those 
#      models to be verified for this 06h FSS job
#   2) Remove existing 06h FSS records from model_$vday.vsdb
#   3) Submit POE job (using exverf_precip_fss_06h_poe.sh as basis for
#      POE script)
#   4) For each model, assemble the individual pieces of VSDBs into a single
#      fss06 vsdb file, then add it to the existing model_$vday.vsdb in the
#      VSDB directory.  
# 
# Log history: 
#    2015-06-29 Copied over from exverf_precip_fss_24h.sh
###############################################################################
set -x

# Create a file called fss.domains that contains domain info of only the models 
# to be verified for FSS_06H in this job:

cat $PARMverf_precip/verf_precip_fss_06h.domains |while read tmp
do
  first_char=`echo $tmp |cut -c1`
  if [ ! "$first_char" = "#" ]   # Skip comment line
  then
    modnam=`echo $tmp |awk -F"|" '{print $1}'`
    let "runmod=run_$modnam"
    if [ $runmod = 1 ]; then echo $tmp >> fss06.domains; fi
  fi
done

# Create a list of models to be verified ('sort -u' ensures that model names
# will be unique - in case of multiple entries in the domain parm file 
# (e.g. nam 00/12Z cycles have different bucket length from the 06/18Z cycles)

cat fss06.domains | awk -F"|" '{print $1}' | sort -u > fss06.model.list

# Go to VSDB directory to remove lines containing 'FSS' and 'APCP/06':

for modnam in `cat fss06.model.list`
do 
  if ! [ -d $COMVSDB/$modnam ]
   then
    mkdir -p $COMVSDB/$modnam
  elif [ -s $COMVSDB/$modnam/${modnam}_${vday}.vsdb ]
  then
    sed -e "/FSS<.*APCP\/06/d" $COMVSDB/$modnam/${modnam}_${vday}.vsdb >$COMVSDB/$modnam/${modnam}_${vday}.vsdb1
    mv $COMVSDB/$modnam/${modnam}_${vday}.vsdb1 $COMVSDB/$modnam/${modnam}_${vday}.vsdb
  fi
done # looping through fss06.model.list

export vgrid=240

#
# Create a script to be poe'd for 6-hours ending at 00/06/12/18:
if [ -e $DATA/poescript ]; then
  rm $DATA/poescript
fi

vhours="00 06 12 18"

for vhr in $vhours
do
  echo $HOMEverf_precip/scripts/exverf_precip_fss_06h_poe.sh $vhr >> $DATA/poescript
done

echo 
echo Here is the poescript for fss06:
cat $DATA/poescript
echo 

#############################################################
# Execute the script.
#############################################################
#mpirun -l cfp poescript
mpiexec  -np 4 --cpu-bind core cfp ./poescript
if [ "$envir" != dev ]; then
  export err=$?; err_chk
fi

for vhr in $vhours
do
  set +x
  echo "######################################"
  echo "  BEGIN FSS06 PROGRAM OUTPUT for validation at ${vday}$vhr}"
  echo "######################################"
  set -x
  cat $pgmout.fss06.$vhr
  set +x
  echo "######################################"
  echo "  END FSS06 PROGRAM OUTPUT for validation at ${vday}$vhr}"
  echo "######################################"
  set -x
done

mkdir -p $DATA/vsdb
cd $DATA

for model in `cat fss06.model.list`
do
  for vhr in 00 06 12 18 
  do 
    cat $vhr/vsdb/subtotal.${vhr}z/${model}_${vday}.vsdb >> $DATA/vsdb/${model}_${vday}.vsdb
  done
  cat $DATA/vsdb/${model}_${vday}.vsdb >> $COMVSDB/$model/${model}_${vday}.vsdb
done

cd $DATA/vsdb

tar cvf ../vsdbfss06.$vday.tar .
cd ..

if [ $SENDCOM = YES ]
then
  cp vsdbfss06.$vday.tar ${COMOUT}.${vday}/. 

  if [ $RUN_ENVIR = dev ]
  then
    if [ ! -d $ARCH45DAY ]; then mkdir -p $ARCH45DAY; fi
    cp vsdbfss06.$vday.tar $ARCH45DAY/.
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
postmsg "$jlogfile" "$msg"

############## END OF SCRIPT #######################
