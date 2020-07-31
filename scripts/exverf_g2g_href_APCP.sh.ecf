#!/bin/ksh
#################################################################
# Script Name: verf_g2g_reflt.sh.sms $vday $vcyc
# Purpose:   To run grid-to-grid verification on reflectivity
#
# Log History:  Julia Zhu -- 2010.04.28 
################################################################
set -x

cd $DATA

echo "$0 STRDATE "`date`

msg="$job HAS BEGUN"
postmsg "$jlogfile" "$msg"

export vday=$1
  
  #yl verf_g2g_href.vars: href|pc3
  cp $PARMverf_g2g/verf_g2g_href.vars vars

  $USHverf_g2g/verf_g2g_get_href.sh ccpa
  $USHverf_g2g/verf_g2g_get_href.sh reference2
  $USHverf_g2g/verf_g2g_get_href.sh href

#yl just model=href, var=pc3
cat vars |while read line
do   
  model=`echo $line |awk -F"|" '{print $1}'` 
  vars=`echo $line |awk -F"|" '{print $2}'`

  for var in $vars ; do
    $USHverf_g2g/verf_g2g_run_href.sh $model $var 
  done

done

msg="JOB $job HAS COMPLETED NORMALLY"
postmsg "$jlogfile" "$msg"

exit 0
