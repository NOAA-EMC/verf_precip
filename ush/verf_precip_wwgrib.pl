#!/usr/bin/perl -w

#
# this script reads a "wgrib -V -PDS gribfile"
# and creates a gribscan-like inventory
# by Wesley Ebisuzaki

# for perl beginners
#  \d    matches any digit
#  \d*   matches any number of digits
#  \s    matches any whitespace
#  \S    matches any non-whitespace

# this program works by reading in the very verbose inventory until
# it reads a blank line (end of record) and the parses the inventory
# and writes what it wants

# the tricky part is getting the minutes field which
# is not part of the normal inventory

$wgrib="/$ENV{WGRIBpath}/wgrib";
#$wgrib="/apps/ops/prod/libs/intel/19.1.3.304/grib_util/1.2.3/bin/wgrib";
#/apps/ops/prod/libs/intel/19.1.3.304/grib_util/1.2.3/bin/wgrib

open (IN, "$wgrib -PDS10 -V $ARGV[0] |");

$line="";
while (<IN>) {
    chomp;                            # strip record separator
    $line="$line $_";                 # $line has the complete inventory

    # check if end of verbose inventory
    if ("$_" eq "") { 
        $_=$line;

        /rec (\d*):/;
        $rec = $1;

	/ grid=(\d*) /;
	$grid = $1;

	/ kpds5=(\d*) /;
	$kpds5 = $1;

	/:date (\d*) /;
	$date = $1;

	/ timerange (\d*) /;
        $timerange = $1;

	/ P1 (\d*) /;
	$p1 = $1;

	/ P2 (\d*) /;
	$p2 = $1;

	/PDS10\S*=(\s*\S*){18}/;
	$minute=$1;

	/ grid=\d* (\S*) /;
        $level = $1;

        / min\/max data (\S*) (\S*) /;
        $min = $1;
        $max = $2;

#       print "$rec // $grid // $kpds5 // $date $p1 $p2 // $timerange // $level // $min $max\n";
	
	printf "%4d %3d %3d %10d%2.2d %3d %3d %3d %7s min/max %9.9g %9.9g\n", 
           $rec, $grid, $kpds5, $date, $minute, $p1, $p2, $timerange, $level, $min, $max; 

        $line="";
    }
}
