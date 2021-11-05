#!/bin/ksh
################################################################################
# Name of Script:  verf_precip_indexplot.sh
# Purpose of Script: to plot side-by-side daily precip verification files.
#
# History:
#
# Usage:  verf_precip_plotpcp_index.sh $vday
#
################################################################################
set -x

cd $DATA
vday=$1

yyyy=`echo $vday | cut -c 1-4`
mm=`echo $vday | cut -c 5-6`
dd=`echo $vday | cut -c 7-8`

typeset -R2 -Z mm dd

set -A mon Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
mname=${mon[mm-1]}

# Now create the index file:
cat > index.html <<EOF
<HTML>
<HEAD>
<CENTER>
<A NAME="TOP"></A>
<TITLE>Precipitation Forecast Verification Valid at 
12Z $dd ${mname} $yyyy</TITLE> 
<H1>Precipitation Forecast Verification Valid at</H1>
<H1>12Z $dd ${mname} $yyyy</H1> 
<P><HR><P>
<A HREF="../$vday.oconus/index.html">Go to this day's OConUS page</A>
<P><HR><P>
<H2> Available Comparisons 
  (format is <I>model.veriftime.forecastlength</I>): </H2>
EOF

icnt=0

if [ -e part.html ]; then
  rm -f part.html
fi
typeset -Z3 fhr

for fhr in 24 27 30 33 36 39 42 45 48 51 54 57 60 63 66 69 72 75 78 81 84 87 90 96 102 108 114 120 126 132 138 144 150 157 162 168 174 180
do
  for model in nam namx namb \
               conusnest conusnestx conusnestz gfs gfsx fv3gfs nssl4arw \
               rap hrrr \
               conusnmmb conusarw conusarw2 firewxcs \
               cmc cmcglb dwd ecmwf jma metfr ukmo hpc medley \
               srmean srmeanx srfreqm srfreqmx \
               ndas ndassoil ndasx ndasxsoil ndasb ndasbsoil \
               ndasz ndaszsoil ndaszc ndaszcsoil \
               ndasref ndasrefsoil
  do
    if [ -e $model.v${vday}12.${fhr}h.gif ]; then
      let icnt=icnt+1
      cat >> index.html <<EOF 
  <A HREF="#VERF${icnt}"> $model.v${vday}12.${fhr}h </A> <BR>
EOF
      cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <TR><TD><IMG SRC="$model.v${vday}12.${fhr}h.gif"></TD>
      <TD><IMG SRC="st4.${vdate}.24h.gif"></TD>
  </TR>
  <A HREF="#TOP">Back to top</A>
</TABLE>
EOF
    fi
  done
done

#This is not done in ops, all of this script is only done in dev
#Will need to uncomment this and figure of the new st4 path after code delivery to NCO
#cp /gpfs/dell2/nco/ops/com/pcpanl/prod/pcpanl.$vday/st4_conus.${vday}12.24h.gif ./st4.${vday}12.24h.gif

# For my own dev job, copy over a blank GIF file as placeholder for the CCPA
# gif; do the same thing for NOHRSC png.  Later util.dev/trans_send2rzdm.ksh 
# will do an "ssh" on emcrzdm to copy over the actual ccpa 24h gif from 
# Yan Luo's directory, and wget the NOHRSC png file. 

# 2018/07/10: NOHRSC 24h snow fall stopped after 29 Jun.
# Note about the mechanism for including the NOHRSC snow fall in the daily 
#   plot: 'wget' can only be done in transfer queue later, when
#   the nohrsc png file will be renamed - if available - to 
#   nohrsc_${vday}12_24h.png.  When we copying over the blankplt.png over here,
#   whether the nohrsc image exists or not, the web page will include listing
#   for nohrsc.  Below is the switch that turns the inclusion of the NOHRSC
#   plot on or off - no need to change the util.dev/trans_send2rzdm.ksh
#
# 2018/09/07: reactivated the inclusion of the nohrsc plot
if [ $RUN_ENVIR = dev -a $LOGNAME = "Alicia.Bentley" -a $machine = wcoss ]; 
then
  cp /meso/save/Alicia.Bentley/utils/blankplt.gif ccpa_${vday}12_24h.gif
  #reactivate when nohrsc data becomes available
  cp /meso/save/Alicia.Bentley/utils/blankplt.png nohrsc_${vday}12_24h.png
fi

for prefix in st2ml rtma mrms_gc mrms_gc_para mrms_mm cpcuni_na
do 
  if [ $prefix = cpcuni_na ]; then
    pcpanl=${prefix}.${vday}12
  elif [ $prefix = rtma -o $prefix = rtmax ]; then
    pcpanl=${prefix}.v${vday}12.024h
  else
    pcpanl=${prefix}.${vday}12.24h
  fi

  if [ -e $pcpanl.gif ]; then
    let icnt=icnt+1
    cat >> index.html <<EOF 
  <A HREF="#VERF${icnt}"> $pcpanl </A> <BR>
EOF
    cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <TR><TD><IMG SRC="$pcpanl.gif"></TD>
      <TD><IMG SRC="st4.${vdate}.24h.gif"></TD>
  </TR>
  <A HREF="#TOP">Back to top</A>
EOF
  fi

done

if [ -e ccpa_${vday}12_24h.gif ]; 
then
  let icnt=icnt+1
  cat >> index.html <<EOF
  <A HREF="#VERF${icnt}">ccpa_${vday}12_24h</A> <BR>
EOF

  # CCPA image needs to be resized: do it separately from 
  # st2ml, mrms etc.:
  cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <TR><TD><IMG SRC="ccpa_${vday}12_24h.gif" width="540"></TD>
      <TD><IMG SRC="st4.${vdate}.24h.gif"></TD>
  </TR>
  <A HREF="#TOP">Back to top</A>
</TABLE>
EOF
fi

if [ -e nohrsc_${vday}12_24h.png ]; 
then
  let icnt=icnt+1
  cat >> index.html <<EOF
  <A HREF="#VERF${icnt}">nohrsc_${vday}12_24h</A> <BR>
EOF

  # NOHRSC image also needs to be resized: 
  cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <TR><TD><IMG SRC="nohrsc_${vday}12_24h.png" width="540"></TD>
      <TD><IMG SRC="st4.${vdate}.24h.gif"></TD>
  </TR>
  <A HREF="#TOP">Back to top</A>
</TABLE>

EOF

fi

cat >> index.html <<EOF
<P><HR><P>
<A HREF="../../index.html">Back to index page</A>
<P><HR><P>
EOF

cat >> part.html <<EOF
<P><HR><P>
<A NAME="OBS"></A>
<A HREF="../../index.html">Back to index page</A>
</CENTER>
EOF

cat part.html >> index.html

exit

