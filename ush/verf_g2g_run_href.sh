#!/bin/ksh
###################################################################
# script: 
#         To run grid-to-grid program for all of single models
#  Author: Binbin Zhou, Apr. 9, 2014
###################################################################
set -x

model=$1
var=$2
ref=namnest

MODEL=`echo $model | tr '[a-z]' '[A-Z]'`

  $USHverf_g2g/verf_g2g_href.sh $vday $model $var $ref
  
  cycles="00 06 12 18"

  if [ ! -d $COMVSDB/${model} ]; then
    mkdir -p $COMVSDB/${model}
  fi

  for ncyc in $cycles ; do
    cat ${MODEL}_${var}_${vday}${ncyc}.vsdb >> $COMVSDB/${model}/${model}_${vday}.vsdb
  done
