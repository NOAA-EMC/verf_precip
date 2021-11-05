A Breif Instruction:

This package is for probabilistic and system verification of HREF(v2) 3hr APCP ensemble 
forecast. The input data include HREF's each member files, hi-resolution CCPA data files 
and NAMNest forecast files which are used as reference (baseline for computing skill scores).
The output  are unified ensemble VSDB files based on which sevral major ensemble
scores can be generated (i.e. from MetViewer).

The running job script is JVERF_GRID2GRID_HREF (in jobs sub-directory), which sets operational
paths and running environment;  then trigger the script exverf_g2g_href_APCP.sh (in scripts)
to do following tasks:

   (1) Parapare and obtain necessary HREF, CCAp and NAMnest APCP input data files
        (using  script verf_g2g_get_href.sh in ush) 
   (2) Run grid2grid source code (in exec) to get VSDB files (using scripts
        verf_g2g_run_href.sh, verf_g2g_href.sh, verf_g2g_prepg2g_grib2.sh, 
        and verf_g2g_fitsg2g_grib2.sh in ush) 

 The VSDB files will be sent to /com/verf/prod in production mode. In dev or testing mode,
they are saved in user defined directory defined in job card

The verification is based on hi-res CCPA 255 grid. That is,  both HREF and NAMnest
files are first interpolate using copygb onto CAPP hires grid, over which the verification is 
conducted.

The verification configuration is set up in verf_g2g_href.pc3 file (in parm): like following

V01 10 HREF/8 8
    1  MODNAM
    6   6
       12
       18
       24
       30
       36
    1  VDATE
    1  CCPA
    1  G255
    1  EFS1
    1  PCP3  1 8 1 0  FHO~ 0 0.01 0.1 0.5 1 3 5 10
    1  P700
EOF

Here, HREF/8 8 means there are 8 members for HREF
MODNAM will be substitued by "HREF" in verification
There are 6 forecast hours will be verified in this case.
VDATE is validation time that will be substituted by a string, for example, like
"2017032806". This setting also indicates the verification is in backward mode.
In other word, one CCAP time cycle data is verified by several previous cycles' 
forecasts. 
CCPA is obvervation type.
G255 is grid number (user defined grid here)
EFS1 indicates ensemble verification case 1. Since this grid2grid package is unified
for both single model  and ensemble. Different verification type settings will use
different subroutines. 
PCP3 is a string (can be any string), followed by a set of product ID: 1 8 1 0, which
indicate APCP's grib2 product pds numbers pds(1), pds(2), pds(10) and pds(12), defined
in GRIB2's Section 4 (Template 4.x);  
Following FHO~ 0 0.01 0.1 0.5 1 3 5 10 indicate verification threshold ranges (in unit mm).
The last P700 is not used for surface field verification.

In parm, files verf_g2g.regions and verf_g2g.grid104 are used for sub-regions. verf_g2g_href.vars
is for model and variable setting. (href|pc3) in this case. file verf_g2g_dev_config is
for setting environment variables in development/testing mode. The testing mode can be triggered
by script jverf_grid2grid_href_00.ecf in ecf. 

 
 
 


   
