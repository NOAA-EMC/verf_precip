#!/bin/ksh
set -x
# 1) run getppt (in retro mode) for GLBFV3 for $daym1
# 2) send fv3gfs_* files  to gyre:/ptmpp1/Ying.Lin/verf.dat/precip.$daym1
if [ $# -eq 0 ]; then   
  today=`date -u +%Y%m%d`
  daym1=`/nwprod/util/ush/finddate.sh $today d-1`
else 
  daym1=$1
fi
daym3=`/nwprod/util/ush/finddate.sh ${daym1} d-2`

/meso/save/Ying.Lin/pcpverif/nextjif/ecf/jverf_precip_getppt.ecf $daym1 retro 

echo 'finished running getppt retro for fv3gfs'

# send to devwcoss:
cd /ptmpp1/Ying.Lin/verf.dat/precip.$daym1
devwcoss=`cat /etc/dev`

ssh Ying.Lin@${devwcoss} "mkdir -p /ptmpp1/Ying.Lin/verf.dat/precip.$daym1/"
scp fv3gfs_* Ying.Lin@${devwcoss}:/ptmpp1/Ying.Lin/verf.dat/precip.$daym1/.

# 2018/08/30: send fv3gfs QPF files to ftp.emc.ncep.noaa.gov for 
# int'l centers, so they can have an early look at it.
rzdmdir=/home/ftp/emc/mmb/precip/fv3gfs
# Only keep two days' worth of data on line:
ssh wd22yl@emcrzdm "rm -rf $rzdmdir/precip.$daym3; mkdir $rzdmdir/precip.$daym1"
scp gfs_*.grb2 wd22yl@emcrzdm:$rzdmdir/precip.$daym1/.

exit


