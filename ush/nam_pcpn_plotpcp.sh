#!/bin/ksh
#############################################################################
# Plot a precip analysis or model forecast using GEMPAK.
# /nwprod/gempak/.gempak was executed in the calling routine
# (so we are not running it unnecessarily when making multiple plots).
# This script is used by pcpanl and pcpverif jobs
# Name of script:    nam_pcpn_plotpcp.sh
#
# Arguments
#  1. 'model' : Model name
#  2. 'vdate' : Verification date/hour
#  3. 'vacc'  : Verification length
#  4: 'grids' : grids to be verified on
#  5: 'cycles': model cycles
#  6: 'bucket': bucket length
#  7: 'frange': range of model forecast
#  8: 'nest'  : special mask?  (nests)
#############################################################################

set -x

GBFILE=$1
GFFILE=$2
DATE=$3
AC=$4
TITLE="$5 ${AC}h Accum (mm) Ending $DATE"

# GDPFUN needs to be p01m/p03m/p24m, etc., so pad $AC with leading zero, if
# necessary.
typeset -R2 -Z AC

# optional argument: region (AK, HI or PR)
if [ $# -gt 5 ]; then 
  region=$6
else
  region=CONUS
fi
  
# GDPFUN needs to be p01m/p03m/p24m, etc., so pad $AC with leading zero, if
# necessary.
typeset -R2 -Z AC
 
GDFILE=${GBFILE}.grd
 
# If for any reason - e.g. job hiccups - the gif file already exists,
# GEMPAK will produce something like "file.gif.2".  We don't want that,
# so check for existing gif.
 
if [ -e $GFFILE ]; then
  rm -f $GFFILE
fi

nagrib << EOFgrib
 GBFILE   = $GBFILE
 INDXFL   =
 GDOUTF   = $GDFILE
 PROJ     =
 GRDAREA  =
 KXKY     =
 MAXGRD   = 4999
 CPYFIL   = GDS
 GAREA    = dset
 OUTPUT   = T
 GBTBLS   = wmogrib.tbl
 GBDIAG   =
 PDSEXT   = NO
 
r
 
ex
 
EOFgrib

echo "Start to plot the precip data"

cat > input_gdplot2 << EOF1
  GDFILE   = $GDFILE
  GLEVEL   = 0
  GVCORD   = none
  GDPFUN   = p${AC}m
  PANEL    = 0/1/1/1
  DEVICE   = gif | $GFFILE | 480;425
  SCALE    = 0
  TYPE     = f
  CONTUR   = 0
  CINT     = 2
  LINE     = 2/1/1/1
  FINT     = 0.1;2;5;10;15;20;25;35;50;75;100;125;150;175
  FLINE    = 31;23;22;21;20;19;10;17;16;15;14;29;28;24;25
  HILO     =
  HLSYM    =
  CLRBAR   = 1/V/LL/.005;.02/.9;.013/|0.50/1
  GVECT    =
  REFVEC   =
  TITLE    = 1/0/$TITLE
  TEXT     = 0.8
  CLEAR    = y
  SKIP     = 0
  MAP      = 1/1/1
  LATLON   = 0
  STNPLT   =
EOF1

if [ $region = CONUS ]; then
  cat >> input_gdplot2 << EOF2
  GAREA    = 18;-124;50;-60
  PROJ     = lcc/35;-95;35 
r
EOF2
elif [ $region = AK ]; then
  cat >> input_gdplot2 << EOF3
  GAREA    = 35;-180;73;-86.5
  PROJ     = nps/22;-165;22
r
EOF3
elif [ $region = HI ]; then
  cat >> input_gdplot2 << EOF4
  GAREA    = 18;-163;23.5;-152
  PROJ     = mer/22;-165;3
r
EOF4
elif [ $region = PR ]; then
  cat >> input_gdplot2 << EOF5
  GAREA    = 13;-77;24;-61
  PROJ     = lcc/20;-68;20
r
EOF5

else 
  echo "Unrecognized region option. Stop."
  exit
fi

$GEMEXE/gdplot2 < input_gdplot2

$GEMEXE/gpend

exit
