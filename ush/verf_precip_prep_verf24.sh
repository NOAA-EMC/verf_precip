#!/bin/ksh
set -x

# This script is the intermediate step between 
#  scripts/exverf_precip_verfgen_24h.sh
# and
#  ush/verf_precip_verf24.sh
# For each item in verf_precip_verf24.domains, this script prepares arguments
#  for ush/verf_precip_verf24.sh, then invokes ush/verf_precip_verf24.sh.
#
# Arguments for verf_precip_verf24.sh:
#  1. Model name
#  2. Verification date/hour
#  3. Verification length
#  4: grids to be verified on
#  5: model cycles
#  6: bucket length
#  7: range of model forecast to be verified.  This is not necessarily the 
#       limit of the model forecast length - e.g. forecast might be out to
#       10 days but only verified for 84 hours, then this number should
#       be '84'.  If this number is '96' and the model has a 12Z cycle,
#       then 96h fcst will be verified.
#  8: special mask?  (nest)

# verf24.domains was created by scripts/exverf_precip_verfgen_24h.sh.sms

cat verf24.domains |while read tmp
do
   first_char=`echo $tmp |cut -c1`
   if [ "$first_char" = "#" ]
   then
     echo "This is a comment line, skip it"
   else
     modnam_m1=${modnam:-none}
     modnam=`echo $tmp |awk -F"|" '{print $1}'`
     vlen=`echo $tmp |awk -F"|" '{print $2}'`
     grids=`echo $tmp |awk -F"|" '{print $3}`
     cycs=`echo $tmp |awk -F"|" '{print $4}'`
     blen=`echo $tmp |awk -F"|" '{print $5}'`
     fcsthour=`echo $tmp |awk -F"|" '{print $6}'`
     #  CONUS 24h verfgen parm file normally has 6 arguments
     # OCONUS 24h verfgen parm file has 7: pur/hwi/ask
     # So the optional 'altcomin' argument is 7th for ConUS, 8th for OConUS. 
     if [ $domain = conus ]; then
       altopt=`echo $tmp |awk -F"|" '{print $7}'`
     else
       nest=`echo $tmp |awk -F"|" '{print $7}'`
       altopt=`echo $tmp |awk -F"|" '{print $8}'`
     fi
     # the above altopt might be empty.  To avoid an error msg in the IF block
     # below, make it a character string of "null" if it does not have a 
     # pre-assigned value.
     altopt=${altopt:-null}
     if [ $altopt = altcomin ]; then
       export COMIN=$COMIN2
     else
       export COMIN=$COMIN1
     fi

#    Since 3-hourly and 24-hourly stats are kept in the same VSDB file, if we
#    make a re-run for the 24-hour, we need to remove the existing 24h stats
#    from the VSDB file and keep the 3h stats.  This is how it is done below:
#      1) Check to see that, within this job, this is the first time "modnam"
#         is being verified (models such as "NAM" might appear multiple times
#         in verf_precip_verfXX.domains, first to be verified over CoNUS, 
#         and again on special sub-regions).  
#      2) If VSDB file for this model/day already exists; if so, delete 
#         all lines containing the string APCP/24 from the VSDB file (in the 
#         case of ConUS verification); or all lines containing 'ASK FHO',
#         'HWI FHO' or 'PUR FHO', in the case of OconUS verif, depending on
#         the particular OConUS region we are verifying.  
#
     let "runmod=run_$modnam"
     if [ $runmod = 1 ]
     then
        if [ $modnam != $modnam_m1 ]
        then
          if [ -s $COMVSDB/$modnam/${modnam}_${vday}.vsdb ]
          then
            # For ConUS verif, delete all VSDB lines with "FHO * APCP/24" 
            #   and "SL1L2 APCP/24".  
            # For OConUS verif, delete all VSDB lines with (say) "HWI FHO" 
            #   and "HWI SL1L2".  We're assuming here that all OConUS verif
            #   will be 24 hourly in the foreseeable future.  
            if [ $domain = conus ]; then
              sed -e "/FHO.*APCP\/24/d;/SL1L2 APCP\/24/d" $COMVSDB/$modnam/${modnam}_${vday}.vsdb >$COMVSDB/$modnam/${modnam}_${vday}.vsdb1
            else
              NEST=`echo $nest | tr "[a-z]" "[A-Z]"`
              sed -e "/$NEST FHO/d;/$NEST SL1L2/d" $COMVSDB/$modnam/${modnam}_${vday}.vsdb >$COMVSDB/$modnam/${modnam}_${vday}.vsdb1
            fi
            mv $COMVSDB/$modnam/${modnam}_${vday}.vsdb1 $COMVSDB/$modnam/${modnam}_${vday}.vsdb
          fi
        fi
        $USHverf_precip/verf_precip_verf24.sh $modnam $vdate $vlen "$grids" "$cycs" $blen $fcsthour $nest
     fi
   fi
done

exit
