#!/bin/ksh

# Quick script to determine which days/cycles are on disk.  Useful for when
# Matt is running the para (pre-NCO run) and devwcoss availability is erratic.
#
# This script is extracted from ush/verf_g2g_get_href.sh.
#
# To run: find_href.sh yyyymmdd (script will go look for cycles 00/06/12/18)

if [ $# -lt 1 ]; then
  echo 'need argument yyyymmdd (vday)'
fi

vday=$1

get_pdy_dir() {
vd=$1
cyc=$2

PDYs=`ls -t /gpfs/hps2/ptmp/Matthew.Pyle/tmpnwprd/href_ensprod_${cyc}_test*/PDY`

for pdy in $PDYs ; do

. $pdy
if [ $PDY = $vd ] ; then
n=`echo "$pdy" | awk '{print index($0, "PDY")}'` 
n_2=$((n-2))
 if [ -s ${pdy:0:$n_2}/12/filename ] ; then
  echo ${pdy:0:$n_2}
  break
 fi
fi

done

}

for cycle in 00 06 12 18 ; do
  COMHREF=$(get_pdy_dir $vday $cycle)
  echo $COMHREF
done

exit

