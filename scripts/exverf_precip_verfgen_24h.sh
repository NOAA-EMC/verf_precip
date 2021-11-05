#!/bin/ksh
###############################################################################
# Name of Script: exverf_precip_verfgen_24h.sh.sms
# Purpose of Script: To generate the 24h (12Z-12Z) precipitation verification 
#   F/H/O and SL1L2 statistics for various operational models to be used by the
#   Forecast Verification System
# Log history:
###############################################################################

set -x

export vdate=${vday}12  # vday exported from J-job
vdaym1=`date -d "$vday - 1 day" +%Y%m%d`

mkdir $DATA/vsdb 

if [ ! -d ${COMOUT}.${vday} ]; then 
  mkdir -p ${COMOUT}.${vday}
fi


# Copy the mask files over:

if [ $domain = conus ]; then
  cp $FIXverf_precip/verf_precip_regmask_211.Z regmask_211.Z
  cp $FIXverf_precip/verf_precip_regmask_212.Z regmask_212.Z
  cp $FIXverf_precip/verf_precip_regmask_218.Z regmask_218.Z
else
  cp $FIXverf_precip/verf_precip_prmask_194.Z prmask_194.Z
  cp $FIXverf_precip/verf_precip_himask_196.Z himask_196.Z
  cp $FIXverf_precip/verf_precip_akmask_198.Z akmask_198.Z
fi

gunzip *mask*.Z

if [ $domain = conus ]; then
  # Save the 24h totals in a directory, to be tarred up later:
  mkdir qpf24h.dir 
  if [ $VERFANL = CCPA ]; then
# Format below works for the old structure, when CCPA was under gens/prod/gefs.
#   Also note name change!
#    ccpa1=$COMCCPA.$vdaym1/18/ccpa/ccpa_conus_hrap_t18z_06h
#    ccpa2=$COMCCPA.$vday/00/ccpa/ccpa_conus_hrap_t00z_06h
#    ccpa3=$COMCCPA.$vday/06/ccpa/ccpa_conus_hrap_t06z_06h
#    ccpa4=$COMCCPA.$vday/12/ccpa/ccpa_conus_hrap_t12z_06h
    ccpa1=$COMCCPA.$vdaym1/18/ccpa.t18z.06h.hrap.conus
    ccpa2=$COMCCPA.$vday/00/ccpa.t00z.06h.hrap.conus
    ccpa3=$COMCCPA.$vday/06/ccpa.t06z.06h.hrap.conus
    ccpa4=$COMCCPA.$vday/12/ccpa.t12z.06h.hrap.conus

    cat > input_acc_ccpa <<EOF
obs
ccpa.
EOF

    for ccpaf in $ccpa1 $ccpa2 $ccpa3 $ccpa4
    do
      $WGRIB $ccpaf > wgrib.out
      if [[ $? -eq 0 && -s wgrib.out ]]; then 
        cat >> input_acc_ccpa <<EOF
$ccpaf
EOF
        ccpaflag=YES
      else
        ccpaflag=NO
        break
      fi
    done

    if [ $ccpaflag = YES ]; then
      $EXECverf_precip/nam_stage4_acc < input_acc_ccpa
      err=$?
      if [ $err -eq 0 ]; then 
        echo $vday ' CCPA' >> $COMVSDB/24h_verf_anl.log
        cp ccpa.$vdate.24h vanl24.$vdate
        cp ccpa.$vdate.24h ${COMOUT}.${vday}/.
      else 
        ccpaflag=NO
        export VERFANL=STAGE4
      fi
    fi
  fi

  if [ $VERFANL = STAGE4 ]; then
    cp $COMINpcpanl/pcpanl.$vday/ST4.${vday}12.24h.gz .
    gunzip ST4.${vday}12.24h.gz 
    if [ -s ST4.${vday}12.24h ]; then
      cp ST4.${vday}12.24h ${COMOUT}.${vday}/.
      cp ST4.${vday}12.24h vanl24.$vdate
      echo $vday ' STAGE4' > ${COMOUT}.${vday}/24h_verf_anl.$vday
      echo $vday ' STAGE4' >> $COMVSDB/24h_verf_anl.log
    else
      echo No valid Stage IV file.  Exit.
      exit
    fi
  fi

  for grid in 211 212 218 
  do
    $COPYGB -g${grid} -i3 -x vanl24.$vdate vanl24.${grid}.$vdate
  done

  cp $PARMverf_precip/verf_precip_verf24.domains verf24.domains
  $USHverf_precip/verf_precip_prep_verf24.sh 

  ##########################################################################
  # Compute 24h and 48h precipitation forecast scores from the average of 8
  # Operational models
  ##########################################################################
  if [ $run_medley = 1 ]
  then
    cd $DATA
    $USHverf_precip/verf_precip_medley24.sh $vdate
  fi
else # if we are verifying OCONUS
  if [ $cronmode = N ]; then
    # Under normal circumstances (when OCONUS verif is run by a cron job), 
    # util.dev/trans_get_oconus_anl.ksh is the first script run by the cron;
    # after getting oconus analyses, the script then submits ecf/verfgen24. 
    # Here, when cronmode=N, the calling sequence is reversed.  We're invoking
    # the script with an argument, $vday, to tell the script not to do the
    # "bsub ecf/verfgen24".  
    $HOMEverf_precip/util.dev/trans_get_oconus_anl.ksh $vday > /lfs/h2/emc/ptmp/Alicia.Bentley/cron.out/getoconusanl.out 2>&1
  fi # If cronmode = Y, then the trans_get_oconus_anl.ksh script has already
     #   been run and placed in ${COMOUT}.${vday}.
     
  # Copy over CMORPH precip files from ${COMOUT}.${vday}
  cmfile1=CMORPH_V0.x_RAW_0.25deg-3HLY_${vdaym1}
  cmfile2=CMORPH_V0.x_RAW_0.25deg-3HLY_${vday}
  cp ${COMOUT}.${vdaym1}/$cmfile1.gz .
  cp ${COMOUT}.${vday}/$cmfile2.gz .

  gunzip $cmfile1 $cmfile2
  if [[ -s $cmfile1 && -s $cmfile2 ]]; then
    echo ${vdaym1}12 > startdate
    ln -sf startdate               fort.11
    ln -sf $cmfile1                fort.21  
    ln -sf $cmfile2                fort.22
    ln -sf cmorph.${vday}12.grb    fort.51
    $EXECverf_precip/nam_cmorph2grb
    $WGRIB cmorph.${vday}12.grb
    err=$?
    if [ $err -eq 0 ]; then
      cmflag=YES
    else
      cmflag=NO
    fi
  else
    cmflag=NO
  fi

  if [ $cmflag = YES ]; then   # proceed to verifying OCONUS
    export VERFANL=CMORPH

    $COPYGB -g194 -i3 -x cmorph.${vday}12.grb vanl24.194.${vday}12
    $COPYGB -g196 -i3 -x cmorph.${vday}12.grb vanl24.196.${vday}12
  
    grep pur $PARMverf_precip/verf_precip_verf24.oconus.domains > verf24.domains
    $USHverf_precip/verf_precip_prep_verf24.sh 

    grep hwi $PARMverf_precip/verf_precip_verf24.oconus.domains > verf24.domains
    $USHverf_precip/verf_precip_prep_verf24.sh 
  fi # cmflag = yes?

  # Get Alaska QPE file. 
  akqpe=QPE.151.${vday}12.24h
  cp $DCOMROOT/$vday/wgrbbul/qpe/$akqpe .
  err=$?
  if [ $err -eq 0 ]; then
    akflag=YES
  else
    akflag=NO
  fi

  if [ $akflag = YES ]; then  
    export VERFANL=AKQPE
    $COPYGB -g198 -i3 -x $akqpe vanl24.198.${vday}12
    grep '|ask' $PARMverf_precip/verf_precip_verf24.oconus.domains > verf24.domains
    $USHverf_precip/verf_precip_prep_verf24.sh 
  fi # $akflag = YES?
fi  # ConUS or OConUS?  

cd $DATA/vsdb

# tar up the VSDB files so job on tempest can fetch them.

if [ $domain = conus ]; then
  tar cvf ../vsdb24.$vday.tar .
else
  tar cvf ../vsdb24.oconus.$vday.tar .
fi
cd ..

# save the *.212 and *.218 files in case we need to re-plot them:

cd $DATA
if [ $domain = conus ]; then
  tar cvfz modpcpsum.$vday.gz *_*.212 *_*.218 vanl24.218.*
else
  tar cvfz modpcpsum.oconus.$vday.gz *_*.194 *_*.196 *_*.198 QPE.151.*.24h cmorph.*.grb
fi

# Save the 24h QPF totals on the original (not necessarily 'native', as they
# are provided to us) grid point:
if [ $domain = conus ]; then
  cd $DATA/qpf24h.dir
  tar cvfz ../24hrawqpf.$vday.gz .
  cd $DATA
  cp 24hrawqpf.$vday.gz ${COMOUT}.${vday}/.
fi 
if [ $SENDCOM = YES ]
then
  cp vsdb24*.$vday.tar ${COMOUT}.${vday}/. 
  cp modpcpsum*.$vday.gz ${COMOUT}.${vday}/.

  if [ $RUN_ENVIR = dev -a $machine = wcoss -a "$ARCH45DAY" != "" ]
  then
    if [ $LOGNAME = "Alicia.Bentley" -o $LOGNAME = "wx22yl" ]
    then
      if [ ! -d $ARCH45DAY ]; then mkdir -p $ARCH45DAY; fi
      cp vsdb24.$vday.tar $ARCH45DAY/.
    fi
  fi

  if [ $SENDDBN = YES ]
  then
    $DBNROOT/bin/dbn_alert MODEL VERIF_PRECIP $job ${COMOUT}.${vday}/vsdb24.$vday.tar
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
