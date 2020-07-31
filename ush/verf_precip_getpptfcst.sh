#!/bin/ksh
################################################################################
# Name of script:    verf_precip_getpptfcst.sh.sms
# Purpose of script: This script extracts the precip data from the model 
#                    forecast and outputs them in the format of 
#                    $model_$yyyy$mm$dd$hh_$hr1_$hr2
#                    where hr1 and hr2 (3-digit) are the beginning and ending 
#                    time of the accumulation period.
#
# History:
#
# Usage:  verf_precip_getpptfcst.sh.sms $input_card
#   There are 7 lines in input_card.$model: 
#     Line 1:
#       arg1: model name (e.g. nam)
#       arg2: grb1/grb2
#       arg3: convert? (e.g. in GFS/MRF, will convert rain rate to rain 
#             accum)
#       arg4: parameter name 
#             GRIB1 default is '061', for GFS is 059, ECMWF is 228
#             GRIB2 default is 'APCP'.  If it is not APCP, specify here.
#     Line 2:
#       grid?  usually '000'
#     Line 3: full input file name/paths, e.g. 
#       /com/nam/prod/nam.20150222/nam.t%{cyc}%z.firewxnest.bgrd3d%{fhr}%.tm00
#     Line 4: yyyymmdd/model_
#     Line 5: cycles, e.g. 00 06 12 18
#     Line 6: all the hours to get: e.g. 03 06 09 ...., 36
#     Line 7: bucket length
################################################################################
set -x

INPUT=$1
set -A line1 `sed -n 1p $INPUT`
model=${line1[0]}
gribtype=${line1[1]}

mod3=${model:0:3}

# default value for convert and gridconv are both 'no'.  
convert=no
gridconv=no
if [ ${#line1[@]} -gt 2 ]; then    # We will do 'convert'.
  if [ ${line1[2]} = convert ]; then
     convert=yes
  elif [ ${line1[2]} = gc ]; then
     gridconv=yes
  else
     echo 'Unrecognized convert option.  STOP.'
     exit
  fi
fi   # Finished processing the input 'convert' argument

if [ ${#line1[@]} -gt 3 ]; then
  if [ $gribtype = grb1 ]; then
    parm=${line1[3]}
  else
    PARM=${line1[3]}
  fi
else
  if [ $gribtype = grb1 ]; then
    parm=061
  else
    PARM=APCP
  fi
fi

typeset -R3 -Z grid parm fhr0 fhr1 fhr2 tabl

grid=`sed -n 2p $INPUT`
OUTPFIX=$COMOUT.`sed -n 4p $INPUT`
OUTPFIX0=$OUTPFIX  # save original, in case of firewx
cycles=`sed -n 5p $INPUT`
fcsthrs=`sed -n 6p $INPUT`
lbucket=`sed -n 7p $INPUT`

if [ $convert = yes -o $gribtype = grb2 ]; then
  # OUTPFIX=/ptmpp1/Ying.Lin/verf.dat/precip.20140825/gfsx_
  # OUTPF=gfsx_
  # OUTDIR=/ptmpp1/Ying.Lin/verf.dat/precip.20140825
  # TMPOUTPFIX=$DATA/gfs/tmp_gfsx_
  #
  # 2016/10/25 for future gfsx in grib2, we need two temp files:
  #   tmp2_gfs_2016102406_042_045 (grib2)
  #   tmp_gfs_2016102406_042_045 (grib1, still in PRATE)
  OUTPF=`echo $OUTPFIX | awk -F "/" '{print $NF}'`
  OUTDIR=`echo $OUTPFIX | sed s/"\/\$OUTPF"//`
  mkdir $DATA/$model
  
  TMPOUTPFIX=$DATA/$model/tmp_$OUTPF

  if [ $gribtype = grb2 ]; then
    TMP2OUTPFIX=$DATA/$model/tmp2_$OUTPF
  fi

  if [ $model = ecmwf ]; then
    ECOUTPFIX=$TMPOUTPFIX
  fi
fi

for cyc in $cycles
do
   # if the model is 'firewx', find out whether this is a ConUS firewx or
   # Alaska firewx run.  Then do 'firewx_* --> firewxcs_*' or 
   #                             'firewx_* --> firewxak_*', accordingly.
   if [ $model = firewx ]; then
     #INFILE=/com2/nam/prod/nam.20161116/nam.t18z.firewxnest.hiresf00.tm00.grib2
     # loc:   /com2/nam/prod/nam.20161116/nam.t18z.firewxnest_location
     # What we want is the string in the nam.t18z.firewxnest_location,
     # which is either 'conus' or 'alaska'.  
     # make up a dummy infile, nam.t18z.firewxnest.hiresf00.tm00
     # substitite '.hiresf00.tm00.grib2' with '_location':
     DUMINFILE=`sed -n 3p $INPUT | sed s/%{cyc}%/$cyc/g | sed s/%{fhr}%/00/g`
     firewxlocfile=`echo $DUMINFILE | sed 's/.hiresf00.tm00.grib2/_location/'`
     firewxloc=`cat $firewxlocfile`
     if [ $firewxloc = 'conus' ]; then
       OUTPFIX=`echo $OUTPFIX0 | sed 's/firewx_/firewxcs_/'`
     elif [ $firewxloc = 'alaska' ]; then
       OUTPFIX=`echo $OUTPFIX0 | sed 's/firewx_/firewxak_/'`
     fi
   fi

   for fhr in $fcsthrs
   do
      fhr2=$fhr
      if [ $lbucket -eq 999 ]; then
        fhr1=0
      elif [ $lbucket -eq 888 ]; then
        # this is for NAM: 00Z/12Z cycles have only a 12h bucket.  At e.g.
        # fhr=81, we need to get the 72h-81h amount.  When we see lbuckek=888,
        # we only specify fhr2 in the wgrib2 search criterion below
        # (e.g. set timestring="-81 hour acc fcst:", rather than 
        # ":72-81 hour acc fcst:".  
        echo do not use fhr1 when using wgrib2 to extract precip record. 
# So far lbucket is only used for GRIB2.  
      else
        let fhr1=$fhr2-$lbucket
      fi

      INFILE=`sed -n 3p $INPUT | sed s/%{cyc}%/$cyc/g | sed s/%{fhr}%/$fhr/g`
      if [ ! -s $INFILE ]; then
        echo $INFILE n/a >> $LOG
        continue
      fi

      if [ $gribtype = grb2 ]; then
        # 'timestring' should look like ":0-3 hour acc[avg] fcst:" 
        # (for lbucket=888, '-3 hour acc[avg] fcst:'.   Use 
        # "perl -pe '$_=int;'" to remove leading zeroes in $fhr1 and $fhr2:
        #
        if [ $PARM = APCP ]; then
          atype=acc
        elif [ $PARM = PRATE ]; then
          atype=ave
        else
          echo $PARM 'is an unrecognized parameter type for GRIB2. EXIT.'
          exit
        fi

        if [ $lbucket -eq 888 ]; then
          timestring='-'`echo $fhr2 | perl -pe '$_=int;'`' hour '`echo $atype`' fcst:'
        else
          # for never-ending buckets, when fhr is e.g. 72h, the timestring 
          # is '0-3 day' rather than '0-72 hour'
          if [ $lbucket -eq 999 ]; then
            let rhr=${fhr2}%24 
            if [ $rhr -eq 0 ]; then
              useday=Y
              let d=${fhr2}/24 
            else
              useday=N
            fi
          else
            useday=N
          fi

          if [ $useday = Y ]; then
            timestring=':0-'`echo $d`' day '`echo $atype`' fcst:'
          else
            timestring=':'`echo $fhr1 | perl -pe '$_=int;'`-`echo $fhr2 | perl -pe '$_=int;'`' hour '`echo $atype`' fcst:'
          fi
        fi

        $WGRIB2 $INFILE -match :$PARM: -match "$timestring" -grib grib2.file > wgrb2.out
        lwgrb2out=`wc -l wgrb2.out | awk '{print $1}'`
        err=$?
        if [ $err -ne 0 ]; then 
          echo Err code for wgrib2 is $err
        else
          if [ $lbucket -ne 888 -a $lwgrb2out -gt 1 ]; then
            # if lbucket is not '888', then fhr1 has been specified and 
            # ideally there should be one precipitation record in the model
            # output that matches the wgrib2 search criteria.  
            # 2015/4/21: Some model output (emc's conusarw etc.) might have
            # Some models might have duplicate copies of precip for the same
            # forecast hour/accumulation length (HiResW ARW used to have two
            # copies of 00-03h forecasts.  Matt later fixed this). To deal
            # with this, when there are duplicates, just use the first 
            # extracted GRIB2 record.  Inventory the new, single-record 
            # wgrib2 file so that the new wgrb2.out has just a single line 
            # for the fcycle operation below (I first tried 
            # 'head -1 wgrb2.out > wgrb2.out' but that yielded an empty file)
            # Even though HiResW ARWs no longer have this problem, some other
            # model might have the same issue later on.  Rather than declaring
            # error and skipping to the next step, issue a warning and take 
            # the last record by default.  
            echo Warning: $lwgrb2out precip records got extracted from $INFILE
            # 2016/2/5: Note that when there are duplicate entries to a grib2
            # file (example: /com2/sref/prod/sref.20160203/03/pgrb/
            #                 sref_arw.t03z.pgrb212.ctl.f03.grib2
            # the above grib2.file would actually contain two identical fields.
            # In the loop below, only the first iteration will get grib2.file
            # renamed to e.g. tmp.srarwctl_2016020303_000_003, and after
            # cnvgrib, srarwctl_2016020303_000_003 in precip.20160203 will
            # contain two identical GRIB1 fields.  The second iteration 
            # will complain of not finding grib2.file (since it has already
            # been re-named to tmp.srarwctl ...) 
          fi

          cat wgrb2.out | while read tmp
          do 
            fcycle=`echo $tmp | awk -F: '{print $3}' | awk -F= '{print $2}'`
            if [ $lbucket -eq 888 ]; then
              # fhr1 has not been specified in the wgrib2 search above.  We'll
              # go through the 'wgrb2.out' listing to find fhr1.  In the case
              # of NAM 00/12h forecasts, there is only one line (a single precip
              # record that has accumulation hour ending at fhr2).
              fhr1=`echo $tmp | awk -F: '{print $6}' | awk -F- '{print $1}'`
            fi
            TMP2OUTFILE=${TMP2OUTPFIX}${fcycle}_${fhr1}_${fhr2}
            OUTFILE=${OUTPFIX}${fcycle}_${fhr1}_${fhr2}
            mv grib2.file $TMP2OUTFILE
            if [ $convert = yes ]; then
              TMPOUTFILE=${TMPOUTPFIX}${fcycle}_${fhr1}_${fhr2}
              $CNVGRIB -g21 $TMP2OUTFILE $TMPOUTFILE
            else
              # if the model name is 'wgnegfs', do not convert to grib1.  Copy
              # to COMOUT directly.  
              if [ $model = wgnegfs ]; then
                # Save grib2 file to be dbn_alerted/ftp'd for int'l centers
                # for fhr2 -le 6h, there are two identical files in $TMP2OUTFILE
                # since (FV3)GFS carry both a 6h bucket and a never-emptying
                # bucket, so for fcst hours of up to 06h, both buckets are 
                # present with identical results (sloppy setup).  Use wgrib2
                # to eliminate the duplication.
                if [ $fhr2 -le 6 ]; then
                  $WGRIB2 $TMP2OUTFILE -for_n 1:1 -grib ${OUTFILE}.grb2
                else
                  cp $TMP2OUTFILE ${OUTFILE}.grb2
                fi
              else
                $CNVGRIB -g21 $TMP2OUTFILE $OUTFILE
              fi
            fi
          done
        fi # if err=0 after using wgrib2 to inventory the extracted grib2 file
        
      else #it's GRIB1 then.  
        # Most model's GRIB1 QPF files are on GRIB Table #2.  Int'l models have
        # idiosyncratic table numbers.
        # 2018/3/6 when cnvgrib'd to grib1, UKMO's table # is '255'.
        if [ $model = jma ]; then
          tabl=3
        elif [ $model = metfr ]; then
          tabl=1
        elif [ $model = ukmo ]; then
          tabl=255
        else
          tabl=2
        fi

        # do not use 'brkout' for ecmwf.  Also remember that we are dealing with
        # daym1 for ecmwf.
        if [ $model = ecmwf ]; then  
          OUTFILE=${ECOUTPFIX}${daym1}${cyc}_000_${fhr2}
         
          export pgm=verf_precip_pcpconform
          . prep_step
          $EXECverf_precip/verf_precip_pcpconform ecmwf $INFILE $OUTFILE
          export err=$?; err_chk
        else 
          cat > cntrlfile << EOF
INPUTF  A200 :($INFILE
KGTYPE  I5   :(${grid})
EOF

          if [ $convert = yes ]; then
            cat >> cntrlfile << EOF
OTPUTF  A200 :($TMPOUTPFIX
EOF
          else
            cat >> cntrlfile << EOF
OTPUTF  A200 :($OUTPFIX
EOF
          fi

          cat >> cntrlfile << EOF
TABLE I3:($tabl)  PARM I3:($parm)  TFLAG I2:(-1)  P1 I3:( -1)  P2 I3:(${fhr2})
----:----|----:----|----:----|----:----|----:----|----:----|----:----|----:---
EOF

# save a copy of cntrlfile in case we need to debug:
          cp cntrlfile cntrlfile.$model.t${cyc}z.${fhr}h

          export pgm=verf_precip_brkout_fcst
          . prep_step

          $EXECverf_precip/verf_precip_brkout_fcst < cntrlfile
          export err=$?; err_chk
        fi #ECMWF or no? 
      fi #GRB2 or GRB1?
   done  # end of the fhr loop
done     # end of the cyc loop

# put fcsthrs in an array 'afcsthrs so we can refer to the individual 
# elements by their indices.
# e.g. fcsthrs="12 24 36 48"
# then ${afcsthrs[0]}=12
#      ${afcsthrs[1]}=24
#      ${afcsthrs[2]}=36
#      ${afcsthrs[3]}=48
#      ${#afcsthrs[@]}=4 (number of array elements)

set -A afcsthrs $fcsthrs

if [ $mod3 = gec -o $mod3 = gep -o $mod3 = gen ]
then
   mod3=gef
fi

if [ $convert = yes ]; then
  cd $DATA/$model
#
  if [[ $model = ecmwf || $model = jma ]]; then
    if [ $model = ecmwf ]; then
      daysub=$daym1
    elif [ $model = jma ]; then
      daysub=$day
    fi

    for cyc in $cycles
    do
      let "index=${#afcsthrs[@]}-1"
      while [ $index -gt 0 ]; do  # process array elements N-1, N-2, ..., 1
        let "indexm1=$index-1"
        fhr2=${afcsthrs[$index]}
        fhr1=${afcsthrs[$indexm1]}
        cat > input_subtract << EOF
mod
$OUTDIR/${model}_
tmp_${model}_${daysub}${cyc}_000_${fhr1}
tmp_${model}_${daysub}${cyc}_000_${fhr2}
EOF
        pgm=verf_precip_diffpcp
        . prep_step

        $EXECverf_precip/verf_precip_diffpcp < input_subtract
        export err=$?; err_chk

        let "index=$index-1"
      done                        # process array elements N-1, N-2, ..., 1
# For the first (i.e. array element 0) file, just copy over:
      fhr0=${afcsthrs[0]}
      cp    tmp_${model}_${daysub}${cyc}_000_${fhr0} \
        $OUTDIR/${model}_${daysub}${cyc}_000_${fhr0}
    done  # cyc

  elif [ $mod3 = gef ]
  then
      
    model_1=$model

    ls -1 tmp_* | sed s/tmp_//g > list
    for file in `cat list`
    do
      pgm=verf_precip_pcpconform
      . prep_step
      $EXECverf_precip/verf_precip_pcpconform $model_1 tmp_$file $OUTDIR/$file 
      export err=$?; err_chk
    done

  elif [ $model = ukmo ]
  then
    # for UKMO, try copying the tmp_ukmo_* directly to ukmo_*, since pcpconform
    # turns its values to all zero, even when I manually set DecScale to 3. 
    ls -1 tmp_* | sed s/tmp_//g > list
    for file in `cat list`
    do
      cp tmp_$file $OUTDIR/$file 
    done
  fi # different 'convert' for different models
fi   # convert?

# 
# If gridconv=yes, we are extracting grid/convective scale model output
# separately, gridscale (parm=62) first, convective scale (parm=63) next.  If
# the 'model name' here ends with 'c', that means the grid scale field
# has already been extracted.  Add them together here.  
#

echo 'gridconv=' $gridconv

if [ $gridconv = yes ]; then
# find out whether the precip type is 'c' or 'g'. 
  typeset -R1 ptype
  ptype=$model

  if [ $ptype = c ]; then
    mod2=$model
    mod1=`echo $model | sed 's/c$/g/'` # replace last 'c' with 'g'
    mod=`echo $model | sed 's/c$//'`  # remove last 'c'

    for file1 in `ls -1 $COMOUT.$day/${mod1}_*`
    do 
      file2=`echo $file1 | sed 's/'$mod1'/'$mod2'/'`
      filetot=`echo $file1 | sed 's/'$mod1'/'$mod'/'`
     
      if [ -s $file1 -a -s $file2 ]; then
        cat > input_combgrdcnvpcp <<EOF
$file1
$file2
$filetot
EOF
        $EXECverf_precip/verf_precip_addgrdcnv < input_combgrdcnvpcp

      fi # if both gridscale and conv files exist

    done # finished adding up gridscale and convective precip for total precip
         # for a particular model  
  fi # $ptype = c
fi   # $gridconv = yes 

exit
