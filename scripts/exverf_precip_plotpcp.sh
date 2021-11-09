#!/bin/ksh
###############################################################################
# Name of Script: exverf_precip_plotdata.sh
# Purpose of Script: to plot the model precip data using GEMPAK
#
# History:
# 
# Usage: exverf_precip_plotdata.sh.sms 
###############################################################################

set -x
cd $DATA

msg="Begin job for $job"
postmsg "$jlogfile" "$msg"

# To make plots with a white background:
cp $HOMEverf_precip/gempak/tables/colors/coltbl.xwp.wbg coltbl.xwp
# To distinguish between "no data" and "zero precip" areas: 
cp $HOMEverf_precip/gempak/tables/grid/wmogrib1.tbl wmogrib.tbl

export vdate=${vday}12   # $vday exported from J-job.

export COMIN=${COMIN}.${vday}
export COMOUT=${COMOUT}.${vday}

# For dev run, define 'PRODWCOSS', in case files needed have not been
# synch'd over to devwcoss.

if [ $RUN_ENVIR = dev ]; then 
  export PRODWCOSS=`cat /etc/prod`
fi 

# Copy the precip data over (generated from the 24h verification job)
# 
if [ $domain = conus ]; then
  tar xvf $COMIN/modpcpsum.$vday.gz

  # 2018/07/19: dev: get ukmo from prod modpcpsum, to plot with python.  
  prdmodpcpsum=${COMIN}/modpcpsum.$vday.gz
  if [ $RUN_ENVIR = dev ]; then 
    tar xvf $prdmodpcpsum `tar tf $prdmodpcpsum | grep ukmo`
  fi

  if [ $RUN_ENVIR = dev -a $machine = wcoss ]; then
    # Copy over modpcpsum.$vday.retro.Z, in case I made a re-run for some
    # models that were missing earlier. 
    # USEPRD4PLT is set in the ECF script (so that when testing for a new
    # production upgrade, this feature than be turned off).
    if [[ $USEPRD4PLT = YES && -s $COMIN/modpcpsum.$vday.retro.gz ]]; then
      tar xvf $COMIN/modpcpsum.$vday.retro.gz
    fi

    # Copy over the production gif files.
    if [ $USEPRD4PLT = YES ]; then
      prodplottar=${COMIN}.${vday}/pcpplot_${vday}12.tar
      if [ -s $prodplottar ]; then
        tar xvf $prodplottar
      else
        # If the file has not been synched to dev:
        scp Alicia.Bentley@${PRODWCOSS}:$prodplottar .
        mv pcpplot_${vday}12.tar pcpplot_prod_${vday}12.tar
        tar xvf pcpplot_prod_${vday}12.tar
      fi
    fi

    # Check to see if para pcpplot tar file already exists.  If so, untar it.
    # this is useful for, say, re-run the thing in order to include runs done
    # on Zeus (in that case both prod and para plot tars already exist, we just
    # need to copy over the Zeus modpcpsum file and plot those).
    if [ -s $COMOUT/pcpplot_${vdate}.tar ]; then
      tar xvf $COMOUT/pcpplot_${vdate}.tar
    fi

    # copy over the Zeus modpcpsum.$vday.gz file
    # disable this part for now: nothing is running on Zeus. 
    # scp Ying.Lin@dtn-zeus.rdhpcs.noaa.gov:/scratch2/portfolios/NCEPDEV/meso/noscrub/Ying.Lin/verf.dat/precip.${vday}/modpcpsum.${vday}.gz zeus.modpcpsum.${vday}.gz
#    err=$?

#
#    if [ $err -eq 0 ]; then
#      gunzip zeus.modpcpsum.${vday}.gz
#      tar xvf zeus.modpcpsum.${vday}
#    fi
  fi # all the extra stuff for $RUN_ENVIR = dev 
else # if domain=oconus
  tar xvf $COMIN/modpcpsum.oconus.$vday.gz
  # Check to see if pcpplot tar file already exists.  If so, untar it.
  # this is useful for, say, re-run the thing in order to include additional
  # model QPF not included in the earlier run.  Since it takes rather a long
  # time to make plots, it's worth it not having to re-make existing plots.
  if [ -s $COMOUT/pcpplot_${vdate}.oconus.tar ]; then
    tar xvf $COMOUT/pcpplot_${vdate}.oconus.tar
  fi
fi

export vhour=24

typeset -R3 -Z fhr fhr0

if [ $domain = conus ]; then
  cp $PARMverf_precip/verf_precip_plotpcp.domains plotpcp.domains
else
  cp $PARMverf_precip/verf_precip_plotpcp.domains.oconus plotpcp.domains
fi

cat plotpcp.domains |while read tmp
do
  first_char=`echo $tmp |cut -c1`
  if [ "$first_char" = "#" ]
  then
    echo "This is a comment line, skip it"
  else
    mod=`echo $tmp |awk -F"|" '{print $1}'`
    hourlist=`echo $tmp |awk -F"|" '{print $2}'`
    grid=`echo $tmp |awk -F"|" '{print $3}'`
    if [ $grid -eq 194 ]; then
      region=PR
    elif [ $grid -eq 196 ]; then
      region=HI
    elif [ $grid -eq 198 ]; then
      region=AK
    else
      region=CONUS
    fi

    for fhr in $hourlist
    do
      pdate=`$NDATE -$fhr $vdate`
      fhr0=`expr $fhr - $vhour`
      GBFILE=${mod}_${pdate}_${fhr0}_${fhr}.$grid
      if [ $region = CONUS ]; then
        GFFILE=${mod}.v${vdate}.${fhr}h.gif
      else
        GFFILE=${mod}.v${vdate}.${fhr}h.$region.gif
      fi

      # The script is used for both prod and para.  In para mode, we bring 
      # over the prod gif files.  Sometimes the para data file (modpcpsum) 
      # contains model GRIB files that are also in prod (e.g. when we 
      # experiment with medley).  To avoid spending time producing plots 
      # that are already present in prod, call the plotpcp script only when 
      #   1) data file exist and is not empty
      #   2) there isn't a non-empty gif file already.
      if [[ -s $GBFILE && ! -s $GFFILE ]]; then
        MOD=`echo $mod | tr '[a-z]' '[A-Z]'`
        $USHverf_precip/nam_pcpn_plotpcp.sh $GBFILE $GFFILE $vdate $vhour "$MOD ${fhr}h Forecast" $region
      fi
    done # for each item in $hourlist
  fi     # if the item in plotpcp.domains is not a comment line
done     # for each item in plotpcp.domains

# Mar 2018: for dev, use python to plot UKMO QPF files.
if [[ $RUN_ENVIR = dev && $domain = conus ]]; then 
  for file in `ls ukmo*.212`
  do
    # get model cycle yyyymmddhh
    cyc=`echo $file | sed -r 's/(\s?\.212)//' | awk -F"_" '{print $2}'`
    # get forecast hour: 
    fhr=`echo $file | sed -r 's/(\s?\.212)//'| awk -F"_" '{print $4}'`
    ukvdate=`$NDATE +$fhr $cyc`
    python $UTLDEVverf_precip/python/plt_anyfld_grb.py $file
    ukpltgif=ukmo.v${ukvdate}.${fhr}h.gif
    convert $file.png $ukpltgif
  done
fi
# Even though Stage IV 24h accum is used as verifying analysis for ConUS, for 
# side-by-side plots we use the CPC 0.25" global analysis (plotting the 
# North America region) as the right-hand-side plot for  ConUS comparison. 
# Skip this for Zeus.  
# 2016/06/03: also plot ConUS MRMS 24h totals.
if [ $RUN_ENVIR = dev -a $machine = wcoss ]; then
  # Copy over the 1/4 deg CPC analysis from /dcom.  Sometimes, say if devwcoss
  # has been down, and the files are not on /dcom, go get it from prodwcoss.
  CPCDIR=$DCOMROOT/prod/$vday/wgrbbul/cpc_rcdas
  cp $CPCDIR/PRCP_CU_GAUGE_V1.0GLB_0.25deg.lnx.$vday.RT cpcfile.$vday
  err=$?
  if [ $err -ne 0 ]; then
    scp Alicia.Bentley@${PRODWCOSS}:$CPCDIR/PRCP_CU_GAUGE_V1.0GLB_0.25deg.lnx.$vday.RT cpcfile.$day
  fi 

  if [ $domain = conus ]; then
    $UTLDEVverf_precip/verf_precip_gradscpcuni_na.ksh $vday
    # Only make the MRMS plots if the plots don't already exist: 
    if [ ! -s mrms_gc.$vdate.24h.gif ]; then
      $UTLDEVverf_precip/plt_mrms_gc.ksh $vday
    fi

# Active when plotting of MRMS gc parallel is desired: 
#    if [ ! -s mrms_gc_para.$vdate.24h.gif ]; then
#      $UTLDEVverf_precip/plt_mrms_gc_para.ksh $vday
#    fi

    if [ ! -s mrms_mm.$vdate.24h.gif ]; then
      $UTLDEVverf_precip/plt_mrms_mm.ksh $vday
    fi 
  else 
    # plot global CPC unified analysis and cmorph:
    $UTLDEVverf_precip/verf_precip_gradscpcuni_glb.ksh $vday
    # plot AKQPE, and CMORPH over HI and PR:
    for region in AK HI PR
    do
      if [ $region = AK ]; then
        GBFILE=akqpe.$vdate.198
        GFFILE=akqpe.$vdate.gif
        $COPYGB -g 198 -i3 -x QPE.151.$vdate.24h $GBFILE
        ANLNAME=AKQPE
      elif [ $region = HI ]; then
        GBFILE=cmorph.$vdate.196
        GFFILE=cmorph.$vdate.hi.gif
        $COPYGB -g 196 -i3 -x cmorph.$vdate.grb $GBFILE
        ANLNAME=CMORPH
      elif [ $region = PR ]; then
        GBFILE=cmorph.$vdate.194
        GFFILE=cmorph.$vdate.pr.gif
        $COPYGB -g 194 -i3 -x cmorph.$vdate.grb $GBFILE
        ANLNAME=CMORPH
      fi
      $USHverf_precip/nam_pcpn_plotpcp.sh \
        $GBFILE $GFFILE $vdate $vhour "$ANLNAME" $region
    done # do loop for plotting analyses over AK/HI/PR
  fi     # OConUS?
fi       # dev?

# Create the index file and send them over to the RZDM server:
vyear=`echo $vdate |cut -c1-4`
vyearmon=`echo $vdate |cut -c1-6`
vday=`echo $vdate |cut -c1-8`

if [ $domain = conus ]; then
  $USHverf_precip/verf_precip_indexplot_conus.sh $vday
else
  $USHverf_precip/verf_precip_indexplot_oconus.sh $vday
fi

# Save the image and html files:
if [ $domain = conus ]; then
  tar -cvf $COMOUT/pcpplot_${vdate}.tar *.gif index.html
else
  tar -cvf $COMOUT/pcpplot_${vdate}.oconus.tar *.gif index.html
fi

# Put the tar file on 45-day rotating archive:
if [ $RUN_ENVIR = dev -a $LOGNAME = "Alicia.Bentley" -a $machine = wcoss -a "$ARCH45DAY" != "" ]
then
  if [ ! -d $ARCH45DAY ]; then mkdir -p $ARCH45DAY; fi
  cp $COMOUT/pcpplot_${vdate}*.tar $ARCH45DAY/.
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


