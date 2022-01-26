#!/bin/ksh
################################################################################
# Name of script:    exverf_precip_getppt.sh.sms
# Purpose of script: This script extracts the precip data from the various 
#   models and outputs them in the format of $model_$yyyy$mm$dd$hh_$hr1_$hr2
#   where hr1 and hr2 (3-digit) are the beginning and ending time of
#   the accumulation period. 
# 
# Programmer: Stephen Awking  
#
# History:           
#
# Usage:  exverf_precip_getppt.sh.sms
#  Models that we currently use:
#  -----------------------------
#  - nam
#  - namx
#  - namy
#  - gfs
#  - ngm
#  - westarw ($day)
#  - eastarw ($day)
#  - westnmm ($day)
#  - eastnmm ($day)
#  - ndas  ($daym1)
#  - ndassoil  ($daym1)
#  - ndasx ($daym1)
#  - ndasxsoil ($daym1)
#  - ndasy ($daym1)
#  - ndasysoil ($daym1)
#  - cmc, 00Z
#  - cmc, 12Z
#  - cmcglb, 00Z
#  - cmcglb, 12Z
#  - dwd 
#  - ecmwf ($daym1)
#  - ukmo ($daym1)
#  - jma
#  - various sref runs
#  - srmean    ($daym1)
#  - srmeanpar ($daym1)
#############################################################################
set -x

cd $DATA

export YWGRIB=$USHverf_precip/verf_precip_ywgrib.pl
export day=$vday # (vday exported from J-job)
export daym1=`date -d "$day - 1 day" +%Y%m%d`
export dayp1=`date -d "$day + 1 day" +%Y%m%d`
export dayp2=`date -d "$day + 2 day" +%Y%m%d`
export yymmdd=`echo $day |cut -c3-8`
export mmdd=`echo $day |cut -c5-8`
export mmddm1=`echo $daym1 |cut -c5-8`
export mmddp1=`echo $dayp1 |cut -c5-8`
export mmddp2=`echo $dayp2 |cut -c5-8`

mkdir -p $COMOUT.${day} $COMOUT.${daym1}

# log of missing files:
export LOG=$COMOUT.${day}/getpptlog.$day
# In case of re-runs: don't remove existing log.  Write out the time a run
# is made, append to the log file (if one already exists)
echo '    ' >> $LOG
echo `date` '   ' Missing files for $day: >> $LOG

typeset -R2 -Z fhr2 
typeset -R3 -Z fhr3

#########################################################################
# Step 0: Process (some) international QPF files. 
#   1) CMC (global and regional) and DWD files only need to be copied
#      over from /dcom to precip.$yyyymmdd
#   2) ECMWF files have unwieldy names.  Name them to something more
#      manageable before running 'brkout_fcst' on them
# The others (JMA, METFR, UKMO) can be fed to brkout_fcst directly
#########################################################################

export ICOM=$DCOMROOT/$day/qpf_verif
export ICOMm1=$DCOMROOT/$daym1/qpf_verif

# Create 'import' directory to store re-named ECMWF files and cnvgrib'd UKMO
# files:
  IMPORT=$DATA/import
  mkdir $IMPORT

if [ $run_ecmwf = 1 ]; then
  cd $IMPORT

# For ECMWF. precip files are in the format of
#   UWD${daym1}1200${mmdd}12001
#   UWD${daym1}1200${mmddp1}12001
#   UWD${daym1}1200${mmddp2}12001
  cp $ICOMm1/UWD${daym1}1200${mmdd}12001 UWD.${daym1}12.24
  cp $ICOMm1/UWD${daym1}1200${mmddp1}12001 UWD.${daym1}12.48
  cp $ICOMm1/UWD${daym1}1200${mmddp2}12001 UWD.${daym1}12.72
fi

# CMC and DWD precip files need to be converted from GRIB2; DWD needs further 
# tweak in pcpconform.

# starting 12z 20160907, cmc_* files on /dcom lost their .grb2 suffix (they're
# still grib2)
if [ $run_cmc = 1 ]; then
  for file in cmc_${day}00_012_036 cmc_${day}12_000_024 cmc_${day}12_024_048
  do
    if [ -s $ICOM/$file ]; then
      $CNVGRIB -g21 $ICOM/$file $COMOUT.$day/$file
    else
      echo $ICOM/$file >> $LOG
    fi
  done
fi 

if [ $run_cmcglb = 1 ]; then
  for file in \
      cmcglb_${day}00_012_036 cmcglb_${day}00_036_060 cmcglb_${day}00_060_084 \
      cmcglb_${day}12_000_024 cmcglb_${day}12_024_048 cmcglb_${day}12_048_072
  do 
    if [ -s $ICOM/$file.grb2 ]; then
      $CNVGRIB -g21 $ICOM/$file.grb2 $COMOUT.$day/$file
    else
      echo $ICOM/$file.grb2 >> $LOG
    fi
  done
fi 

# 2014/7/1: DWD files changed to GRIB2 format on 2014/6/25!  
if [ $run_dwd = 1 ]; then
  for file in dwd_${day}00_012_036 dwd_${day}00_036_060 \
              dwd_${day}12_000_024 dwd_${day}12_024_048 dwd_${day}12_048_072
  do
    if [ -s $ICOM/$file ]; then
      # 2015/1/28: the suffix of intermediate file name below needs to be 
      # '.tmp' - it's hardwired for DWD pcpconform.  Don't change it. 
      $CNVGRIB -g21 $ICOM/$file $file.tmp
      if [ $? = 0 -a -s $file.tmp ]; then 
        $EXECverf_precip/verf_precip_pcpconform dwd $file.tmp $file
        cp $file $COMOUT.$day/.
      fi
    else
      echo $file >> $LOG
    fi
  done
fi 

if [ $run_ukmo = 1 ]; then
  cd $IMPORT
  for file in ukmo.${day}00 ukmo.${day}12
  do
    $CNVGRIB -g21 $ICOM/$file $file.grb1
  done
fi 

# End of getting the international data

cd $DATA

########################################
# Now start retrieving NCEP model data:
########################################
cp $PARMverf_precip/verf_precip_input.domains input.domains
cat input.domains | while read tmp
do
  # skip the comment lines
  first_char=`echo $tmp |cut -c1`
  if [ $first_char = "#" ]
  then
    echo "It's a comment line, skip this line"
  else
    modnam=`echo $tmp |awk -F"|" '{print $1}'`
    mod3=${modnam:0:3}  # for fv3* or the new GFS that will be FV3GFS.
    let "getmod=run_$modnam"
    if [ "$getmod" = 1 ]
    then
      convert=`echo $tmp |awk -F"|" '{print $2}'`
      gribparm=`echo $tmp |awk -F"|" '{print $3}'`
      grid=`echo $tmp |awk -F"|" '{print $4}'`
      input_file=`echo $tmp |awk -F"|" '{print $5}'`
      output_file=`echo $tmp |awk -F"|" '{print $6}'`
      cycles=`echo $tmp |awk -F"|" '{print $7}'`
      shour=`echo $tmp |awk -F"|" '{print $8}'`
      ehour=`echo $tmp |awk -F"|" '{print $9}'`
      intv=`echo $tmp |awk -F"|" '{print $10}'`
# lbucket is the desired bucket length, which is not the same as output 
# interval, to deal with models with multiple bucket lengths.  Example of such
# models: 
#   'ARW' models tend to have multiple bucket lengths: 1h/3h/48h.  
#   HRRR has 1h/15h.  
# we are currently only using it for when gribtype=grb2 (HRRR).  At fcsthr
# of 3/6/9/12/15, We'll get precip for 00-03h, 00-06h, ..., 00-15h, and skip
# the 02-03h, 05-06h, ..., 14-15h files.
# When bucket length is '999', we assume never-emptied bucket.  When bucket
# length is not given, lbucket defaults to '0' - no bucket length specified, 
# get everything ending at $fhr.  
# 
      lbucket=`echo $tmp |awk -F"|" '{print $11}'`
      lbucket=${lbucket:-0}      # default to '0' if unspecified in parm file
      gribtype=`echo $tmp |awk -F"|" '{print $12}'`
      gribtype=${gribtype:-grb1} # default to 'grb1' if unspecified in parm file

      rm -f input_card.${modnam}
      echo "$modnam  $gribtype $convert $gribparm" >input_card.${modnam}
      echo "$grid" >>input_card.${modnam}
      echo "$input_file" >>input_card.${modnam}
      echo "$output_file" >>input_card.${modnam}
      echo "$cycles" >>input_card.${modnam}

      # Create the hourlist
      hourlist=""
      fhr=$shour

# hourlist looks like this: "03 06  ... 99 102 105 108 ..." for most models.
# for fv3gfs/future gfs.v15, it looks like: "003 006  099 102 105 ...".
# and ditto for the new GFS to be implemented in Jan 2019 that is currently
# (in 2017-2018) called FV3GFS.  'wgne' gfs is [fv3]gfs that we will be posting
# for the international centers, so the 3-digit prefix 'wgn' is included here.
# Unfortunately the regional FV3 does NOT share this characteristics (its 
# forecasdt hours are "03 06 09 ... 60" in the output file names), so the 
# earlier set up of checking whether "$mod3 = fv3" does not work.  
# following works for the GFSv15 when its output is to be named 'gfs' (not
# "fv3gfs":
# 
      while [ $fhr -le $ehour ]
      do
        if [[ $fhr -le 99 && ! $mod3 = gfs && ! $mod3 = wgn ]]; then
          fhr2=$fhr
          hourlist="$hourlist $fhr2"
        else
          fhr3=$fhr
          hourlist="$hourlist $fhr3"
        fi
        let "fhr=fhr+intv"
      done
      echo "$hourlist" >>input_card.${modnam}
      echo "$lbucket"  >>input_card.${modnam}

      sed -e "s/_DAY_/$day/g" -e "s/_DAYm1_/$daym1/g" input_card.${modnam} >input_card.${modnam}.1
      perl -pi -e s/_verGEFS_/${gefs_ver}/g input_card.${modnam}.1
      perl -pi -e s/_verGFS_/${gfs_ver}/g input_card.${modnam}.1
      perl -pi -e s/_verNAM_/${nam_ver}/g input_card.${modnam}.1
      perl -pi -e s/_verHIRESW_/${hiresw_ver}/g input_card.${modnam}.1
      perl -pi -e s/_verRAP_/${rap_ver}/g input_card.${modnam}.1
      perl -pi -e s/_verHRRR_/${hrrr_ver}/g input_card.${modnam}.1
      perl -pi -e s/_verSREF_/${sref_ver}/g input_card.${modnam}.1
      mv input_card.${modnam}.1 input_card.${modnam}
    
      $USHverf_precip/verf_precip_getpptfcst.sh input_card.${modnam}
    fi # run_$modnam = 1?  (from verf_precip_ppt_config)
  fi   # This is a comment line in verf_precip_input.domains?
done   # Go through each line in verf_precip_input.domains

#########################################
# Now start to get the NDAS precip data:
#########################################
for mod in `cat $PARMverf_precip/verf_precip_input_ndas.domains`
do
   let "getmod=run_$mod"
   if [ $getmod = 1 ]
   then
     rm -f input_card
     cp $PARMverf_precip/verf_precip_input_$mod input_card
     sed -e "s/_DAY_/$day/g" -e "s/_DAYm1_/$daym1/g" input_card >input_card.$mod
     perl -pi -e s/_verNAM_/${nam_ver}/g input_card.$mod

     $USHverf_precip/verf_precip_getpptndas.sh input_card.$mod
   fi
done

#####################################################################
#
# Send GFS precip files to NOMADS for international 
# centers to fetch.
if [ $SENDDBN = YES ]
then
  cd $COMOUT.${day}
  for gfsfile in `ls -1 wgnegfs_*.grb2`
  do
    $DBNROOT/bin/dbn_alert MODEL VERIF_PRECIP $job ${COMOUT}.${day}/$gfsfile
  done
fi

#####################################################################
# GOOD RUN
set +x
echo "**************$job COMPLETED NORMALLY on `date`"
set -x
#####################################################################

msg="HAS COMPLETED NORMALLY!"
echo $msg
if [ "$RUN_ENVIR" != dev ]    
then
  postmsg "$jlogfile" "$msg"
fi
############## END OF SCRIPT #######################
