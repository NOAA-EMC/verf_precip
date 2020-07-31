#!/bin/ksh
set -x
day1=20151001
day2=20151111

day=$day1

while [ $day -le $day2 ]
do
  g2p_qcdlygauges.ksh $day
  day=`finddate.sh $day d+1`
done
exit


