#!/bin/ksh
################################################################################
# Name of script:    verf_precip_getpptndas.sh.sms
# Purpose of script: This script extracts the precip data from NDAS and outputs
#                    it in the format of $model_$yyyy$mm$dd$hh_$hr1_$hr2 where 
#                    hr1 and hr2 (3-digit) are the beginning and ending time of
#                    the accumulation period.
# Files used: ndas.t[cyc]z.egrdsf
# History:
#
# Usage:  verf_precip_getpptndas.sh.sms $input_card
# Format of the input card:  [optional argument: grb2] 
#
# cat > input_card.ndas << EOF
# ndas
# ndas_${daym1}12_000_003 /com/nam/prod/ndas.$day/ndas.t00z.egrdsf03.tm12 [grb2]
# ndas_${daym1}12_003_006 /com/nam/prod/ndas.$day/ndas.t00z.egrdsf03.tm09 [grb2]
# ndas_${daym1}12_006_009 /com/nam/prod/ndas.$day/ndas.t06z.egrdsf03.tm12 [grb2]
# ndas_${daym1}12_009_012 /com/nam/prod/ndas.$day/ndas.t06z.egrdsf03.tm09 [grb2]
# ndas_${daym1}12_012_015 /com/nam/prod/ndas.$day/ndas.t12z.egrdsf03.tm12 [grb2]
# ndas_${daym1}12_015_018 /com/nam/prod/ndas.$day/ndas.t12z.egrdsf03.tm09 [grb2]
# ndas_${daym1}12_018_021 /com/nam/prod/ndas.$day/ndas.t18z.egrdsf03.tm12 [grb2]
# ndas_${daym1}12_021_024 /com/nam/prod/ndas.$day/ndas.t18z.egrdsf03.tm09 [grb2]
# EOF
################################################################################
set -x

if [ $# -lt 1 ]
then 
   echo "Invalid Argument"
   echo "Usage: verf_precip_getpptfcst.sh $input_card"
   err_exit
fi
   
INPUT=$1

# Read in model name from the input card:
narg=`sed -n 1p $INPUT | wc -w`
model=`sed -n 1p $INPUT | awk '{print $1}'`

gribtype=grb1  # unless specified otherwise below.
if [ $narg -gt 1 ]; then
  arg2=`sed -n 1p $INPUT | awk '{print $2}'`
  if [ $arg2 = grb2 ]; then
    gribtype=grb2
  fi
fi

# Read in the two arguments for each EDAS segment: 1 - output suffix;

typeset -R3 -Z parm tbl

# if the 'model name' contains the word 'soil' then it is assumed that
# it is 'edasxsoil', 'namzsoil' etc. and will be processed as the 
# land-surface precipitation accumulation (LSPA, table 130, parm 154).

mkdir $model

inqsoil=`echo $model | grep soil | wc -l`

if [ $inqsoil -eq 1 ]; then
  convert=yes
  tbl=130
  parm=154
  if [ $gribtype = grb2 ]; then
    PARM=LSPA
  fi
else 
  convert=no
  tbl=2
  parm=061
  if [ $gribtype = grb2 ]; then
    PARM=APCP
  fi
fi

nline=`wc -l $INPUT`
let "linecnt = 2"

rm -f cntrlfile

while [ $linecnt -le $nline ]; do
   INFILE=`sed -n ${linecnt}p $INPUT | awk '{print $2}'`
  OUTFILE=`sed -n ${linecnt}p $INPUT | awk '{print $1}'`

  if [ $gribtype = grb2 ]; then OTPUTF2=$model/$OUTFILE.grb2; fi

  if [ $convert = yes ]; then
    OTPUTF=$model/$OUTFILE
    CNVTDF=$COMOUT.${daym1}/$OUTFILE
  else
    OTPUTF=$COMOUT.${daym1}/$OUTFILE
  fi

# if $INFILE does not exist, or if the size is zero, note in 
# $LOG, skip remaining commands in the loop:

  if ! [ -s $INFILE ]; then
    echo $INFILE n/a >> $LOG
    let "linecnt = $linecnt + 1"
    continue
  fi

# 2016/06/07: prod NDAS is in GRIB1 with 3h accumulation; NDASX (NAMRR catchup)
# is in GRIB2, with 1h accumulation.  There is no reason to believe that
# either would have more than one precip or LSPA field or more than one bucket.
# So take a chance for NAMX: just get either APCP or LSPA, with no regard to
# bucket lengh.
  if [ $gribtype = grb2 ]; then
    $WGRIB2 $INFILE -match :$PARM: -grib grib2.file > wgrb2.out 
    lwgrb2out=`wc -l wgrb2.out | awk '{print $1}'`
    err=$?
    if [ $err -ne 0 ]; then 
      echo Err code for wgrib2 is $err
    else
      if [ $lwgrb2out -eq 1 ]; then
        mv grib2.file $OTPUTF2
        $CNVGRIB -g21 $OTPUTF2 $OTPUTF
      else
        # for NDAS, there's no reason to have duplicate APCP/LSPA records in a
        # model output (some arw output used to have duplicate APCPs in early
        # 2015). 
        echo Warning: $lwgrb2out precip records got extracted from $INFILE
        continue
      fi
    fi 

  else # input file is grib1. 
    cat >> cntrlfile << EOF
INPUTF  A120 :($INFILE
KGRID   I3   :(000)
OTPUTF  A120 :($OTPUTF
TABLE I3:($tbl)  PARM I3:($parm)  TFLAG I2:(-1)  P1 I3:(  0)  P2 I3:(  3)
EOF

    export pgm=verf_precip_brkout_ndas
    . prep_step

    $EXECverf_precip/verf_precip_brkout_ndas < cntrlfile
    export err=$?; err_chk
  fi # model output is grb1 or grb2?

  # needs to do 'convert' for LSPA, whether the original file is grb1 or grb2:
  if [ $convert = yes ]; then
    
    export pgm=verf_precip_pcpconform
    . prep_step

    $EXECverf_precip/verf_precip_pcpconform $model $OTPUTF $CNVTDF
    export err=$?; err_chk
  fi

  let "linecnt = $linecnt + 1"

done

exit

