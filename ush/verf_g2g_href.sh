#!/bin/ksh
#############################################################
#  verf_g2g_ensemble.sh: to run g2g ensemble package 
#  Author: Binbin Zhou/IMSG
#          Dec 12, 2014     
#############################################################
set -x

VDAY=$1
model=$2
export var=$3
ref=$4
MM=`echo ${VDAY} | cut -c 5-6`
DD=`echo ${VDAY} | cut -c 7-8`

# following parameters are exported to prepg2g.sh ###############
# (1) for observation and forecaste file's names/directories (forecsat's are put
#     in following if block

export obsvdir=${obsvdir:-$OBSVDIR}
export fcstdir=${fcstdir:-$FCSTDIR}

#(2) tendency options
export tnd03='close'
export tnd06='close'
export tnd12='close'
export tnd24='close'

#(4) cloud base starting from where
export cloud_base_from_sfc="no"

#(5) lat_weight="no"
###################################################################

if [ $var = 'pc3' ] ; then

  grid=255
  for m in 01 02 03 04 05 06 07 08 09 10 11 ; do
     MODEL[${m}]=href.ens${m}
  done 
  HH=00 # initial validation hour
  END=18

  NMODEL=10
  export ohead=ccpa
  export ogrbtype=g255.f00
  export otm=
  export otail=
  export fgrbtype=apcp.f
  export ftm=.grib2

fi

typeset -Z2 HH

while [ $HH -le $END ] ; do  # loop for different validation time  

   cp $PARMverf_g2g/verf_g2g_href.$var .
   rm -f g2g.ctl.ensemble
   m=1
   NMODEL=10
   while [ $m -le $NMODEL ] ; do
     export fhead=${MODEL[$m]} 
     sed -e "s/MODNAM/${MODEL[$m]}/g" -e "s/VDATE/$vday$HH/g" verf_g2g_href.$var > user.ctl.${MODEL[$m]} 
     $USHverf_g2g/verf_g2g_prepg2g_grib2.sh < user.ctl.${MODEL[$m]} > output.prepg2g.${MODEL[$m]}
     cat g2g.ctl.${MODEL[$m]} >> g2g.ctl.ensemble
     echo "prepg2g_grib2.sh done for " ${MODEL[$m]}
     m=`expr $m + 1`
   done 
   $USHverf_g2g/verf_g2g_cp_single_Ref_exref.sh $ref $grid <g2g.ctl.ensemble
   $USHverf_g2g/verf_g2g_fitsg2g_grib2.sh<temp

 #HREFv3 aditional 42 fhr with 8 members, Binbin Z. 05//28/2020
 #HREFv3 member9,and 10 only reach up to 36fhr. In other word, for 
 #42fhr  8 members are available

   cp $PARMverf_g2g/verf_g2g_href_f42.$var .
   rm -f g2g.ctl.ensemble
   m=1
   NMODEL=8
   while [ $m -le $NMODEL ] ; do
     export fhead=${MODEL[$m]}
     sed -e "s/MODNAM/${MODEL[$m]}/g" -e "s/VDATE/$vday$HH/g" verf_g2g_href_f42.$var > user.ctl.${MODEL[$m]}
     $USHverf_g2g/verf_g2g_prepg2g_grib2.sh < user.ctl.${MODEL[$m]} > output.prepg2g.${MODEL[$m]}
     cat g2g.ctl.${MODEL[$m]} >> g2g.ctl.ensemble
     echo "prepg2g_grib2.sh done for " ${MODEL[$m]}
     m=`expr $m + 1`
   done
   $USHverf_g2g/verf_g2g_cp_single_Ref_exref.sh $ref $grid <g2g.ctl.ensemble
   $USHverf_g2g/verf_g2g_fitsg2g_grib2.sh<temp



  #Binbin Z: 20210331: HREF 06 and 18Z cycles runs only have 4 members reach fhr48
  # while 00 Z and 12Z have 7 members can reach fhr48. 
  if [ $HH -eq 0 ] || [ $HH -eq 12 ] ; then

   cp $PARMverf_g2g/verf_g2g_href_f48.$var .
   rm -f g2g.ctl.ensemble

   m=1
   NMODEL=7
   while [ $m -le $NMODEL ] ; do
     export fhead=${MODEL[$m]}
     sed -e "s/MODNAM/${MODEL[$m]}/g" -e "s/VDATE/$vday$HH/g" verf_g2g_href_f48.$var > user.ctl.${MODEL[$m]}
     $USHverf_g2g/verf_g2g_prepg2g_grib2.sh < user.ctl.${MODEL[$m]} > output.prepg2g.${MODEL[$m]}
     cat g2g.ctl.${MODEL[$m]} >> g2g.ctl.ensemble
     echo "prepg2g_grib2.sh done for " ${MODEL[$m]}
     m=`expr $m + 1`
   done

   $USHverf_g2g/verf_g2g_cp_single_Ref_exref.sh $ref $grid <g2g.ctl.ensemble
   $USHverf_g2g/verf_g2g_fitsg2g_grib2.sh<temp

  elif [ $HH -eq 6 ] || [ $HH -eq 18 ] ; then

   cp $PARMverf_g2g/verf_g2g_href_f48_4mbr.$var .
   rm -f g2g.ctl.ensemble

   m=1
   NMODEL=4
   while [ $m -le $NMODEL ] ; do
     export fhead=${MODEL[$m]}
     sed -e "s/MODNAM/${MODEL[$m]}/g" -e "s/VDATE/$vday$HH/g" verf_g2g_href_f48_4mbr.$var > user.ctl.${MODEL[$m]}
     $USHverf_g2g/verf_g2g_prepg2g_grib2.sh < user.ctl.${MODEL[$m]} > output.prepg2g.${MODEL[$m]}
     cat g2g.ctl.${MODEL[$m]} >> g2g.ctl.ensemble
     echo "prepg2g_grib2.sh done for " ${MODEL[$m]}
     m=`expr $m + 1`
   done

   $USHverf_g2g/verf_g2g_cp_single_Ref_exref.sh $ref $grid <g2g.ctl.ensemble
   $USHverf_g2g/verf_g2g_fitsg2g_grib2.sh<temp

  fi 

   echo "verf_g2g_fitsg2g_grib2.sh done for " ${VDAY}${HH}

   HH=`expr $HH + 6`

done

exit

