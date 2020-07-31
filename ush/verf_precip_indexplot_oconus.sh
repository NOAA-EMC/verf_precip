#!/bin/ksh
################################################################################
# Name of Script:  verf_precip_indexplot.sh
# Purpose of Script: to plot side-by-side daily precip verification files.
#
# History:
#
# Usage:  verf_precip_plotpcp_index_oconus.sh $vday
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

fhours="24 27 30 33 36 39 42 48 54 60"
regions="PR HI AK"

# Now create the index file:
cat > index.html <<EOF
<HTML>
<HEAD>
<CENTER>
<A NAME="TOP"></A>
<TITLE>OCONUS Precipitation Forecast Verification Valid at 
12Z $dd ${mname} $yyyy</TITLE> 
<H1>OCONUS Precipitation Forecast Verification Valid at</H1>
<H1>12Z $dd ${mname} $yyyy</H1> 
<P><HR><P>
<A HREF="../$vday/index.html">Go to this day's ConUS page</A>
<P><HR><P>
<H2> Available Comparisons 
  (format is <I>model.veriftime.forecastlength</I>): </H2>
EOF

icnt=0

if [ -e part.html ]; then
  rm -f part.html
fi
typeset -Z3 fhr

# the 1st and 2nd plots are CMORPH and CPC global unif'd anl, each by itself.
# Domain for CMORPH is 60S-60N.
if [ -e cmorph.${vday}12.gif ]; then
   let icnt=icnt+1
   cat >> index.html <<EOF 
     <A HREF="#VERF${icnt}"> cmorph.${vday}12.24h.global</A> <BR>
EOF
   cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <IMG SRC="cmorph.${vday}12.gif">
</TABLE>
EOF
fi

if [ -e cpcuni_glb.${vday}12.gif ]; then
   let icnt=icnt+1
   cat >> index.html <<EOF 
     <A HREF="#VERF${icnt}">cpcuni_glb.${vday}12</A> <BR>
EOF
   cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <IMG SRC="cpcuni_glb.${vday}12.gif">
</TABLE>
EOF
fi

# Copy over the PR Stage IV image (from para for now):
cp /com2/pcpanl/prod/pcpanl.$vday/st4_pr.${vday}12.24h.gif .
if [ -s st4_pr.${vday}12.24h.gif -a -s cmorph.$vdate.pr.gif ]; then
   let icnt=icnt+1
   cat >> index.html <<EOF 
     <A HREF="#VERF${icnt}">st4_pr.${vday}12.24h</A> <BR>
EOF
   cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <TR><TD><IMG SRC="st4_pr.${vday}12.24h.gif"></TD>
      <TD><IMG SRC="cmorph.$vdate.pr.gif"></TD>
  </TR>
  <A HREF="#TOP">Back to top</A>
</TABLE>
EOF
fi
  

for region in `echo $regions`
do 
  if [ $region = PR ]; then
    GFANL=cmorph.$vdate.pr.gif
  elif [ $region = HI ]; then
    GFANL=cmorph.$vdate.hi.gif
  elif [ $region = AK ]; then
    GFANL=akqpe.$vdate.gif
  fi

  for fhr in ` echo $fhours`
  do
    for model in nam namx gfs gfsx fv3gfs prnest prnestx prnmmb prarw prarw2 hinest hinestx hinmmb hiarw hiarw2 aknest aknestx alaskarr aknmmb akarw akarw2 hrrrak rap firewxak
    do
      if [ -e $model.v${vday}12.${fhr}h.$region.gif ]; then
        let icnt=icnt+1
        cat >> index.html <<EOF 
          <A HREF="#VERF${icnt}"> $model.v${vday}12.${fhr}h.$region</A> <BR>
EOF
        cat >> part.html <<EOF   
<A NAME="VERF${icnt}"></A>
<TABLE border=0 cellspacing=0 cellpadding=0>
  <TR><TD><IMG SRC="$model.v${vday}12.${fhr}h.$region.gif"></TD>
      <TD><IMG SRC="$GFANL"></TD>
  </TR>
  <A HREF="#TOP">Back to top</A>
</TABLE>
EOF
      fi
    done
  done
done

cat part.html >> index.html

cat >> index.html <<EOF
<P><HR><P>
<A HREF="../$vday/index.html">Go to this day's ConUS page</A>
<P><HR><P>
EOF

exit

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

