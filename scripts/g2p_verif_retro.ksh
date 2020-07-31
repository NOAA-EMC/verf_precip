#!/bin/ksh
set -x
# Given a pair of gridded 24h precip vs. 24h list of gauge data, check each
# gauge site against gridded data to find nearest match, print out both in 
# an ascii file (to make scatter plots later).

day1=20151103
day2=20151127
day=$day1

while [ $day -le $day2 ]; do

daym1=`finddate.sh $day d-1`

yyyy=`echo $day | cut -c 1-4`
goodarch=/meso/save/Ying.Lin/good-usa-dlyprcp/$yyyy
goodgaugefile=good-usa-dlyprcp-$day
exedir=/meso/save/Ying.Lin/pcpverif/nextjif/exec
exedirx=/meso/save/Ying.Lin/pcpverif/nextjif/sorc/verif_precip_g2pt.fd

archive=/meso/save/Ying.Lin/verf.grid2gauge.dat

if [ ! -d $archive ]; then mkdir -p $archive; fi

wrkdir=/stmpp1/Ying.Lin/g2p_verif
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

pcpanldir=/ptmpp1/Ying.Lin/verf.rtma/prod_nam_pcpn_anal.$day
cp $pcpanldir/ST2.${day}12.24h.gz .
pcpanldirx=/ptmpp1/Ying.Lin/verf.rtma/para_nam_pcpn_anal.$day
cp $pcpanldirx/ST2x.${day}12.24h.gz .
cp $pcpanldirx/ST4.${day}12.24h.gz .

gunzip *.gz

verfdat=/ptmpp1/Ying.Lin/verf.rtma/precip.$daym1

# use the 'obs' option to sum rtma so the resulting 24h total would have
# the ending hour of the 24h period in the file name.  
cat > input_rtma << EOF
obs
rtma.
$verfdat/rtma_${daym1}12_000_003
$verfdat/rtma_${daym1}12_003_006
$verfdat/rtma_${daym1}12_006_009
$verfdat/rtma_${daym1}12_009_012
$verfdat/rtma_${daym1}12_012_015
$verfdat/rtma_${daym1}12_015_018
$verfdat/rtma_${daym1}12_018_021
$verfdat/rtma_${daym1}12_021_024
EOF

cat > input_rtmax << EOF
obs
rtmax.
$verfdat/rtmax_${daym1}12_000_003
$verfdat/rtmax_${daym1}12_003_006
$verfdat/rtmax_${daym1}12_006_009
$verfdat/rtmax_${daym1}12_009_012
$verfdat/rtmax_${daym1}12_012_015
$verfdat/rtmax_${daym1}12_015_018
$verfdat/rtmax_${daym1}12_018_021
$verfdat/rtmax_${daym1}12_021_024
EOF

$exedir/nam_stage4_acc < input_rtma

$exedir/nam_stage4_acc < input_rtmax

for anl in ST2 ST2x ST4 rtma rtmax 
do
  anlfile=${anl}.${day}12.24h
  if [ -s $anlfile ]; then
    ln -sf $anlfile               fort.11
    ln -sf $goodgaugefile         fort.12
    ln -sf g2p_${anl}_${day}.dat  fort.51   
    ln -sf g2p_${anl}_${day}.notmatched  fort.52
    $exedirx/verf_precip_grid2gauge
  fi
done

mv g2p_*_${day}.dat $archive/.

day=`finddate.sh $day d+1`
done

exit

