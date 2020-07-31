#!/bin/ksh
# set -x  do not use verbose mode: too many lines.
# In /com/hourly/prod/gaugeqc, check 
# usa-dlyprcp-$yyyymmdd against $yyyymmdd.evalU to throw out entries in
# dlyprcp that that had been flagged by gaugeqc.
#
# if the script is called w/o an argument, the J-job's vday is used. 
if [ $# = 1 ]; then
  vday=$1
fi

gaugeqcdir=/gpfs/dell1/nco/ops/com/hourly/prod/gaugeqc
gaugefile=$gaugeqcdir/usa-dlyprcp-$vday

evalU=$gaugeqcdir/$vday.evalU
goodgaugefile=good-usa-dlyprcp-$vday
tossgaugefile=toss-usa-dlyprcp-$vday

cd $DATA

# make a file with just a list of the bad daily gauges, skip the header line
#  'yyyymmdd.evalU'
awk '{print $1}' $evalU | sed '1d' > badgauges.$vday

# Go through usa-dlyprcp-$vday, skip the header line
#  '24-hr precip reports ending 12Z on yyyymmdd'

nline=0
cat $gaugefile |while read tmp
do
  let nline=nline+1
  if [ $nline -eq 1 ]; then continue; fi  
  staid=`echo $tmp | awk '{print $4}'`
  goodid=Y
  for badid in `cat badgauges.$vday`
  do 
    if [ $staid = $badid ]; then
      sed -n ${nline}p $gaugefile >> $tossgaugefile
      goodid=N
      break
    fi
  done

  if [ $goodid = Y ]; then
    sed -n ${nline}p $gaugefile >> $goodgaugefile
  fi
done

# for some reason if yyyy/goodarch were defined before the do loop the loop
# won't proceed!! 

cp $goodgaugefile $tossgaugefile ${COMOUT}.${vday}/.

exit
