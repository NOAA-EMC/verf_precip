#!/bin/ksh
set -x
# Given a pair of gridded 24h precip vs. 24h list of gauge data, check each
# gauge site against gridded data to find nearest match, print out both in 
# an ascii file (to make scatter plots later).

if [ $# = 0 ]; then
  today=`date +%Y%m%d`
  vday=`finddate.sh $today d-8`
else
  vday=$1
fi

vdaym1=`finddate.sh $vday d-1`

yyyy=`echo $vday | cut -c 1-4`

export HOMEverf_precip=$ZROOT/pcpverif/v3.4.0
export DATAROOT=/stmpp1/$LOGNAME/tmpnwprd.v3.4.0
exedir=$HOMEverf_precip/exec

goodarch=/meso/save/Ying.Lin/good-usa-dlyprcp/$yyyy
goodgaugefile=good-usa-dlyprcp-$vday

archive=/meso/save/Ying.Lin/verf.grid2gauge.dat

if [ ! -d $archive ]; then mkdir -p $archive; fi

wrkdir=$DATAROOT/verf_grid2gauge
if [ -d $wrkdir ]; then
   rm -f $wrkdir/*
else
  mkdir -p $wrkdir
fi

cd $wrkdir
cp $goodarch/$goodgaugefile .
err=$?

if [ $err -ne 0 ]; then 
  echo Error getting $goodgaugefile.  EXIT.
  exit
fi

verfproddir=/com/verf/prod/precip.$vday
verfparadir=/ptmpp1/Ying.Lin/verf.dat.v3.4.0/precip.$vday
pcpanldir=/com/hourly/prod/nam_pcpn_anal.$vday
cp $verfproddir/ccpa.${vday}12.24h .
cp $verfparadir/ccpa.${vday}12.24h ccpax.${vday}12.24h
cp $pcpanldir/ST4.${vday}12.24h.gz .

cp ccpa* ST4.* $archive/.
gunzip ST4.${vday}12.24h.gz

for anl in ST4 ccpa ccpax
do
  anlfile=${anl}.${vday}12.24h
  if [ -s $anlfile ]; then
    ln -sf $anlfile               fort.11
    ln -sf $goodgaugefile         fort.12
    ln -sf g2g_${anl}_${vday}.dat  fort.51   
    ln -sf g2g_${anl}_${vday}.notmatched  fort.52
    $exedir/verf_precip_grid2gauge
  fi
done

cp g2g_*_${vday}.dat $archive/.

python $HOMEverf_precip/util.dev/python/anl_vs_gauge_scatter.py $vday
cp scat.$vday.png $archive/.

exit

