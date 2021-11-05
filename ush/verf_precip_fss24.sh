#!/bin/ksh 

#############################################################################
# Name of script:    verf_precip_fss24h.sh
# Purpose of script: This script generate the 24h precipitation Fractional
#                    Skill Scores
# Arguments for this script:
#  1. 'model'    : Model name
#  2. 'vgrid'    : Verification grid
#  3: 'cycles'   : model cycles
#  4: 'frange'   : range of model forecast
#  5: 'nest'     : special mask?  (nests)
#############################################################################
set -x

cd $DATA

model=$1
export vgrid=$2
cycles=$3
frange=$4

# 'vday' was exported from parent script.  We need to export 'vdate' for fss.f
# to be used in the VSDB.
export vdate=${vday}12

# Build the model directory on the repository server (Currently CCS):
if [ ! -d $COMVSDB/$model ]; then
  mkdir -p $COMVSDB/$model
fi

if [ $# -eq 5 ]; then
  nest=$5
else
  nest=no
fi

# export upper-case model name to fss.f (the model name in the vsdb
# file will be in upper case):

export MODNAM=`echo $model | tr "[a-z]" "[A-Z]"`

# Set the variable length, they are now all 3-digit:
typeset -Z3 t0 t1 t2 tbgn tend fhour

#############################################################################
#Step 1: Determine the initial forecast hour to reach the verification time:
#
# vacc : verification length (24h):
# fhour: forecast hour to reach verification time, e.g. the '60' in 
# the vsdb line 'V01 ETA 60 2002080112'.

# In the main loop, find the initial forecast hour ( fhour -ge 24h), 
# and increment it by fhrincr (forecast hour increment).

# Go through all cycles in the input "cycles" to determine the initial 
# forecast hour, which is the smallest number (-ge 24h) that will reach
# the verification time (12Z) for one of the cycles.  
# 
#     cycle       forecast hour
#      00            36
#      03            33
#      06            30
#      09            27
#      12            24
#      15            45
#      18            42
#      21            39
#
# i.e. for cyc -le 12, fhour=36-$cyc
#      for cyc -gt 12  fhour=24+$cyc
#
# First set fhour to a maximum value (should be < 48h), then go through
# all the cycles to find the smallest fhour:
#############################################################################

fhour=48

for cyc in $cycles
do
  if [ $cyc -le 12 ]; then
    let "fhr=36-$cyc"
  else
    let "fhr=60-$cyc"
  fi

  if [ $fhour -gt $fhr ]; then
    fhour=$fhr
  fi
done

# export fhour for verfgen24.f
export fhour

#############################################################################
#Step 2: Determine all the available files to be used in the verification
#
# This script was originally designed to increment forecast length
# by bucket length, with the assumption that bucket length would be
# shorter than the model cycle increments (Example 1: GFS has four
# cycles each day, so the 'cycle increment' is 6h, and the bucket
# length is 6h.  Example 2: NMMCENT is run once a day, so the 'cycle
# increment' is 24

# Increment for the main loop ('while') is the number of hours between
# two consecutive model cycles to be verified ('fhrincr').  For example,
# NMMCENT is verified once a day, so fhrincr=24.  Eta is verified
# four times a day ("00 06 12 18") so fhrincr=06.  
# Count the number of model cycles each day (e.g. "00 06 12 18" returns '4'):
#############################################################################
ncyc=`echo $cycles | wc -w`

if [ $ncyc -eq 1 ]; then
  fhrincr=24
else
  cyc1=`echo $cycles | awk '{print $1}'`
  cyc2=`echo $cycles | awk '{print $2}'`
  let "fhrincr=$cyc2-$cyc1"
fi

#############################################################################
# The following 'while' loop (increment: "fhour = $fhour + $bucket") 
# 
# Example 1: nam 2009052412 218 218 "00 06 12 18" 84
#   fhrincr=06
#
#   Round 1: fhour=24
#            mdate=2009052312   ! forecast starting time (i.e. model cycle)
#            cyc=12             ! model cycle
#            24hsum=nam_2009052312_000_024.218
#
#   Round 2: fhour=30
#            mdate=2009052306
#            cyc=06
#            24hsum=nam_2009052306_006_030.218
# 
#   Round 3: fhour=36
#   Round 4: fhour=42
#   Round 5: fhour=48
#   Round 6: fhour=54
#   
#############################################################################
while [ $fhour -le $frange ]
do 
  mdate=`$NDATE -$fhour $vdate`  
  mday=`echo $mdate | cut -c 1-8`  
  myear=`echo $mdate | cut -c 1-4`  

  let "tbgn = $fhour - 24"
  tend=$fhour

  accfile=${model}_${mdate}_${tbgn}_${tend}
  modfile=${model}_${mdate}_${tbgn}_${tend}.$vgrid

# extract the 24h QPF file from $COMIN.$vday/24hrawqpf.$vday.gz (by-product
# of VERFGEN24):
  tar xvf $COMIN.$vday/24hrawqpf.$vday.gz ./$accfile 
  if [ $? -eq 0 ]; then
    if [ $vgrid -eq 240 ]; then
      gridhrap="255 5 1121 881 23117 -119023 8 -105000 4763 4763 0 64"
      $COPYGB -g "$gridhrap" -i3 -x $accfile $modfile
    else
      $COPYGB -g ${vgrid} -i3 -x $accfile $modfile
    fi

#   Not doing subregions now, just ConUS (CNS)
    if [ $nest = no ]; then
      export region=CNS
      maskfile=stage3_mask.grb
    else
      echo 'Unrecognized nest option: only doing FSS on ConUS for now.  Exit'
      exit
    fi
  
    vsdb1=vsdb.$model.$fhour.$vgrid

#    pgm=verf_precip_fss
#    . prep_step
#    msg="`date` -- $pgm for fss_24h started"
#    postmsg "$jlogfile" "$msg"

# This is so we can tell from the screen which node the job is currently 
# running on: 
    hostname

    ln -sf $modfile        fort.11
    ln -sf ccpa.$vdate.24h         fort.12
    ln -sf $maskfile               fort.13
    ln -sf vsdb/$vsdb1             fort.51
      
    startmsg
    $EXECverf_precip/verf_precip_fss
    export err=$?; err_chk

    cat vsdb/$vsdb1 >> $COMVSDB/$model/${model}_${vday}.vsdb
    cat vsdb/$vsdb1 >> vsdb/${model}_${vday}.vsdb

  fi # if the $vtime (e.g.24h) sum of model precip exists:

  let "fhour = $fhour + $fhrincr"  
done

exit 0
