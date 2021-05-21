#!/bin/ksh
set -x

modnam=$1

if [ $modnam = ccpa ] ; then
  cycles="00 06 12 18"
   for cyc in $cycles ; do
     ccpa=$COMCCPA.${vday}/$cyc/ccpa.t${cyc}z.03h.hrap.conus.gb2
     cp $ccpa $COMOUT/ccpa.t${cyc}z.g255.f00 
   done
fi 
    
if [ $modnam = reference2 ] ; then

  cycles="00 06 12 18"

  for cyc in $cycles ; do
   for fhr in 06 12 18 24 30 36 42 48 ; do

     namnest=$COMNAM.${vday}/nam.t${cyc}z.conusnest.hiresf${fhr}.tm00.grib2
     $WGRIB2 -match ":APCP:surface" $namnest |$WGRIB2 -i  $namnest -grib  $DATA/apcp
     $COPYGB2 -g"20 6 0 0 0 0 0 0 1121 881 23117000 240977000 8 60000000 255000000 4763000 4763000 0 64" -i2,1 -x $DATA/apcp $COMOUT/namnest.t${cyc}z.apcp.f${fhr}.grib2

     rm -f $DATA/apcp

    done
   done

fi


if [ $modnam = href ] ; then

  yyyy=${vday:0:4}
  mm=${vday:4:2}
  dd=${vday:6:2}

  for cycle in 00 06 12 18 ; do
    for fhr in 06 12 18 24 30 36 42 48; do
      for mbr in 01 02 03 04 05 06 07 08 09 10; do
#        href=${COMHREF}.${vday}_expv3/verf_g2g/href.m${mbr}.t${cycle}z.conus.f${fhr}
#       use 'prcip' below, instead of href.m*?        
        href=${COMHREF}.${vday}/verf_g2g/prcip.m${mbr}.t${cycle}z.conus.f${fhr}
        if [ -s $href ]; then 
# YL: 
#         find field that matches ":APCP:surface" in $href, output it to 
#         apcp, then copygb2 to HRAP grid.

          $WGRIB2 -match ":APCP:surface" $href |$WGRIB2 -i $href -grib $DATA/apcp
          $COPYGB2 -g"20 6 0 0 0 0 0 0 1121 881 23117000 240977000 8 60000000 255000000 4763000 4763000 0 64" -i2,1 -x $DATA/apcp $DATA/href.ens${mbr}.t${cycle}z.apcp.f${fhr}

          #HREFv2 grid resolution has been changed
        
          echo "255 $yyyy $mm $dd $cycle $fhr href.ens${mbr}.t${cycle}z.apcp.f${fhr}"|$EXECverf_g2g/verf_g2g_re-set-time
          mv href.ens${mbr}.t${cycle}z.apcp.f${fhr}.new $COMOUT/href.ens${mbr}.t${cycle}z.apcp.f${fhr}.grib2
        else
          echo $href not found. 
        fi
      done
    done
  done 

  for cycle in 00 12 ; do
     mv $COMOUT/href.ens08.t${cycle}z.apcp.f48.grib2  $COMOUT/href.ens04.t${cycle}z.apcp.f48.grib2
  done

  for cycle in 06 18 ; do
     mv $COMOUT/href.ens05.t${cycle}z.apcp.f48.grib2  $COMOUT/href.ens04.t${cycle}z.apcp.f48.grib2
  done

fi
