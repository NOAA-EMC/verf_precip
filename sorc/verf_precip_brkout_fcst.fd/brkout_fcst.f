      PROGRAM BRKOUTFCST
!$$$  MAIN PROGRAM DOCUMENTATION BLOCK
!                .      .    .     
! SUBPROGRAM:    BRKOUT      READS GRIB1 FILE AND WRITES OUT PIECES 
!   PRGRMMR: BALDWIN         ORG: W/NMC2     DATE: 95-04-06
!     
! ABSTRACT:
!   This program extracts fields from a grib 1 forecast file and breaks 
!   it into smaller pieces.  the way it breaks it up is determined by a 
!   control file read in from unit 5.  
!     
! PROGRAM HISTORY LOG:
!   93-??-??  MARK IREDELL
!   93-10-05  RUSS TREADON - ENHANCED COMMENTS
!   95-04-05  MIKE BALDWIN - COMBINE RDGRBI AND GRIBIT TO MAKE
!                              BRKOUT
!   95-11-08  MIKE BALDWIN - FIX UP TO NOT UNPACK ORIG DATA
!                            PREV VERSION WAS INCR NO OF BITS
!   95-11-22  MIKE BALDWIN - PATCH CLD INFO ON ETA (SINCE POST IS WRONG)
!   96-09-24  MIKE BALDWIN - CHANGE CNTRL FILE READ TO MATCH OLD FORMAT
!   97-02-19  MIKE BALDWIN - UPDATE FOR NEW VERSION OF POST
!   99-05-05  MIKE BALDWIN - IBM SP VERSION USING WGRIB
!   00-02-25  MIKE BALDWIN - ADD P1 AND P2 TO PDS SEARCH PARMS
! 2001-12-12  Ying Lin     - Enable grid number as optional selection criterion
! 2003-01-02  Ying Lin     - Input/output file lengthened from A60 to A80
! 2003-06-02  Ying Lin     - Simplified the code by using 'wwgrib' to 
!                            produce formatted grib inventory (instead of 
!                            searching for field separators in wgrib output. 
!                        
! 2003-09-11  Ying Lin     - Input/output file lengthened from A80 to A120
!                            to accommodate WRF testing
! 2004-02-17  Ying Lin     - Output model precip file with 3-digit forecast
!                            hours (e.g. eta_2004021712_015_018) instead
!                            of 2-digits we have been using, which limit
!                            forecast verification to 4 days.
! 2005-08-09  Ying Lin     - Got rid of level and type of level information; 
!                            Added optional GRIB parameter table number in the
!                            input card.
! 2012-07-23  Y. Lin:      - Convert to ifort for Zeus/WCOSS
! 
!   INPUT FILES:
!     input card read in from standard input unit 5:
! INPUTF  A200 :(/emc2/wx20jd/RSM/dataout/ens.2004022221/ras_pgrb212.p2.f63
! KGRID   I3   :(000)
! OTPUTF  A200 :(/ptmp/wx22yl/verif/archive/20040222/srrrasp2_
! TABLE I3:( -1)  PARM I3:(061)  TFLAG I2:(-1)  P1 I3:( -1)  P2 I3:(084)
! ----:----|----:----|----:----|----:----|----:----|----:----|----:----|----:-
! 1234567890   123456789012   1234567890123  1234567890   1234567890
!
! What is in the input card:
!  1st line: grib file to extract from
!  2rd line: grid to extract from.  '0' means grid is not a criterion
!            in performing the extraction.
!  3th line: prefix for extracted grib file (subset of input grib file)
!  4th line: 
!     Parm #1: jpds(19), Version of parameter table (usually 2; 130 for
!              land surface parms)
!          #2: jpds( 5), parameter number (i.e. 61 for rain accum)
!          #3: jpds(16), time range flag
!          #4: jpds(14), time range 1
!          #5: jpds(15), time range 2
!
!     FORT.12 - Input GRIB 1 DATA FILE 
!
!   OUTPUT FILES:
!     FORT.6  - RUNTIME STANDARD OUTPUT.
!     
!   SUBPROGRAMS CALLED:
!     UTILITIES:
!       WWGRIB (formatted wgrib output)
!       YWGRIB (like wwgrib, but also output GRIB table number - first column
!         after record number).
!     
!   ATTRIBUTES:
!     LANGUAGE: FORTRAN
!
!$$$  
!
      INTEGER STDOUT
      INTEGER JPDS5,JPDS6,JPDS7,JPDS16,JPDS14,JPDS15,JPDS19
!
      CHARACTER INFILE*200,OPFIX*200,OUTFILE*200,DATSTM*18,CMD*750,           &
                CREC*4, YWGRIB*200, WGRIBpath*200, CFMT*23
!
!  DATSTM: date/hour and accumulation part of the extracted precip file:
!      nam_2006122712_078_081
!          ----:----|----:----|
!  CFMT: format for writing out the above: CFMT="(i10,'_',I3.3,'_',I3.3)"
!                                                ----:----|----:----|---
!
      DATA  STDOUT/  6 /
      DATA  LCNTRL/ 5 /
      DATA  LCNTRL2/ 11 /
!     
!**************************************************************************
!     START BRKOUT HERE.
!
!     READ THROUGH THE CNTRL FILE:
! Line 1: input file name
! Line 2: grid number
! Line 3: output path/file prefix
! Line 4: PDS values
!   JPDS(19) - version of parameter table
!   JPDS( 5) - parameter number
!   JPDS(16) - time range flag
!   JPDS(14) - time range 1
!   JPDS(15) - time range 2
      READ(LCNTRL,'(15X,A200)',END=9999) INFILE
      READ(LCNTRL,'(15X,I3)')            KGRID
      READ(LCNTRL,'(15X,A200)')          OPFIX
      READ(LCNTRL,2010) JPDS19,JPDS5,JPDS16,JPDS14,JPDS15
 2010 FORMAT(10X,I3,12X,I3,13X,I2,10X,I3,10X,I3)

      WRITE(STDOUT,*) ' INPUT FILE =',INFILE
      WRITE(STDOUT,*) ' OUTPUT GRID TYPE =',KGRID
!
!     GET INDEX FILE FROM YWGRIB
!
      CLOSE(UNIT=LCNTRL2)
      KLENIN=LEN_TRIM(INFILE)
!
! Where is 'ywgrib' on the system?  Get path/command from calling script.
! Note: if you're testing the executable from this code directly, without
! a calling script, you'll need to do an "export YWGRIB= ..." first.
!
      call getenv("YWGRIB",YWGRIB)
      kyw=len_trim(YWGRIB)
!
      CMD=YWGRIB(1:kyw)//' '//infile(1:klenin)//' >outfile.ywgrib'
!
      lencmd=len_trim(CMD)
#ifdef XLF
! Use this for XLF Fortran:
      CALL SYSTEM(CMD(1:lencmd),IER)
#else
! Use this for Intel Fortran:
      IER=SYSTEM(CMD(1:lencmd))
#endif

      OPEN(UNIT=LCNTRL2,FILE='outfile.ywgrib')
!
! Format of ywgrib output:
!   1   2 212  61 200306012100  54  57   4     sfc min/max         0       7.6
!   2   2 212  61 200306012100  51  57   4     sfc min/max         0      16.3
! For gfs (3-digit hours):
!  29   2 126  59 200402231200 240 252   3     sfc min/max         0  0.001473
!----:----|----:----|----:----|----:----|----:----|----:----|----:----|----:--
!
! Read through each record in the wwgrib output:
 20   continue
      read(LCNTRL2,2040,end=100) nrec,itable,igrid,iparm,idate,ip1,ip2
 2040 format(i4,x,i3,x,i3,x,i3,x,i10,2x,2(1x,i3))
!
! Check the PDS of the current record against the input card.  Do we want
! to extract this record?
!
      IF ((JPDS5.EQ.iparm.OR.JPDS5.EQ.-1).AND.                                &
          (JPDS14.EQ.ip1.OR.JPDS14.EQ.-1).AND.                                &
          (JPDS15.EQ.ip2.OR.JPDS15.EQ.-1).AND.                                &
          (KGRID.EQ.igrid .OR. KGRID.EQ.0 .OR. KGRID.EQ.-1).AND.              &
          (JPDS19.EQ.-1 .OR. JPDS19.EQ.itable)) THEN
        CFMT="(i10,'_',I3.3,'_',I3.3)"
        WRITE(DATSTM,CFMT) idate,ip1,ip2
        KLENOPFX=LEN_TRIM(OPFIX)
        OUTFILE=OPFIX(1:KLENOPFX)//DATSTM
        KLENOUT=LEN_TRIM(OUTFILE)
!
! Write out record number nrec to character string crec.  Use variable
! format statement to make it left-justified:
!
        if (nrec .lt. 10) then
          ni=1
        elseif (nrec .lt. 100) then
          ni=2
        elseif (nrec .lt. 1000) then
          ni=3
        else
          ni=4
        endif
        write(crec,2060) nrec
 2060   format(i<ni>)
!
! This is what 'CMD' should look like (path of mean.t09z.f57 omitted for 
! clarity), to
! get the 4th record from SREF emsemble mean file mean.f09z.f57:
!
!   wgrib mean.t09z.f57 | egrep "(^4:)" | wgrib -i mean.t09z.f57 \\
!    -grib -o /ptmp/wx22yl/verif/archive/20030601/srmean_2003060109_033_057
!
      call getenv("WGRIBpath",WGRIBpath)
      kpath=len_trim(WGRIBpath)
        CMD=WGRIBpath(1:kpath)                                                 &
          //'/wgrib '                                                         &
          // INFILE(1:klenin)                                                 &
          // ' | egrep "(^'                                                   &
          // crec(1:ni)                                                       &
          // ':)" | '                                                         &
          // WGRIBpath(1:kpath)                                                &
          // '/wgrib -i '                                                     &
          // INFILE(1:klenin)                                                 &
          // ' -grib -o '                                                     &
          // OUTFILE(1:klenout)                                                
        lencmd=len_trim(CMD)
!
#ifdef XLF
! Use this for XLF Fortran:
        CALL SYSTEM(CMD(1:lencmd),IER)
#else
! Use this for Intel Fortran:
        IER=SYSTEM(CMD(1:lencmd))
#endif

      ENDIF
!
!   TRY NEXT RECORD in the ywgrib output:
!
      GOTO 20

 100  CONTINUE
!     
!     END OF PROGRAM
!     
 9999 STOP
      END
