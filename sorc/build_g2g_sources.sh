#!/bin/sh
set -x
module reset
module use ../modulefiles
module load VERF_PRECIP

module list

sleep 1

BASE=`pwd`

if [ -d $BASE/../exec ]; then
  rm -f $BASE/../exec/verf_g2g_grid2grid_grib2
  rm -f $BASE/../exec/verf_g2g_re-set-time
else
  mkdir $BASE/../exec
fi

##############################

cd ${BASE}/verf_g2g_grid2grid_grib2.fd
make clean
make
make mvexec
make clean

##############################

cd ${BASE}/verf_g2g_reset.fd
make clean
make
make mvexec
make clean

##############################


