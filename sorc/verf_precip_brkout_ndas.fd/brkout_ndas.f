      PROGRAM BRKOUTNDAS
!$$$  MAIN PROGRAM DOCUMENTATION BLOCK
!                .      .    .     
! SUBPROGRAM:    BRKOUT      READS GRIB1 FILE AND WRITES OUT PIE!ES 
!   PRGRMMR: BALDWIN         ORG: W/NMC2     DATE: 95-04-06
!     
! ABSTRACT:
!   This program extracts fields from a grib 1 'edas' file and breaks 
!   it into smaller pieces.  the way it breaks it up is determined by a 
!   control file read in from unit 5.  This is similar to brkout_fcst.f. 
!   The difference: input card for brkout_fcst.f specifies output prefix, 
!   and the forecast time range suffix (e.g. "_057_060") is added in the
!   program.  In contrast, input card for brkout_edas.f specifies the
!   entire output file (so we can call the files
!      $yyyymmdd12_000_003, $yyyymmdd12_003_006, ..., $yyyymmdd12_021_024.
!   wouldn't have worked otherwise).
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
! 2012-07-30  Y. Lin:      - Convert to ifort for Zeus/WCOSS
! 
!   INPUT FILES:
!     input card read in from standard input unit 5:
! INPUTF  A200 :(/com/nam/prod/ndas.20070501/ndas.t00z.egrdsf03.tm12
! KGRID   I3   :(000)
! OTPUTF  A200 :(/ptmp/wx22yl/verif/archive/20070430/edas_2007043012_000_003
! TABLE I3:(  2)  PARM I3:(061)  TFLAG I2:(-1)  P1 I3:( -1)  P2 I3:( -1)
! ----:----|----:----|----:----|----:----|----:----|----:----|----:----|----:-
!
! What is in the input card:
!  1st line: grib file to extract from
!  2nd line: grid to extract from.  '0' or '-1' means grid is not a criterion
!            in performing the extraction.
!  3rd line: path/name of extracted grib file (subset of input grib file)
!  4th line: 
!     Parm #1: jpds(19), Version of parameter table (usually 2; 130 for
!              land surface parms)
!     Parm #2: jpds( 5), parameter number (i.e. 61 for rain accum)
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
!$$$  
!
      INTEGER STDOUT
      INTEGER JPDS5,JPDS6,JPDS7,JPDS16,JPDS14,JPDS15,JPDS19
!
      CHARACTER INFILE*200,OUTFILE*200,CMD*500,                               &
                CREC*4, YWGRIB*200, WGRIBpath*200
!
      DATA  STDOUT/  6 /
      DATA  LCNTRL/ 5 /
      DATA  LCNTRL2/ 11 /
!     
!**************************************************************************
!     START BRKOUT HERE.
!
!     READ THROUGH THE CNTRL FILE:
!     
 10   continue
      READ(LCNTRL,'(15X,A200)',END=9999) INFILE
      READ(LCNTRL,'(15X,I3)')            KGRID
      READ(LCNTRL,'(15X,A200)')          OUTFILE
      READ(LCNTRL,2010) JPDS19,JPDS5,JPDS16,JPDS14,JPDS15
!TABLE I3:(130)  PARM I3:(154)  TFLAG I2:(-1)  P1 I3:(  0)  P2 I3:(  3)
!----:----:----:----:----:----:----:----:----:----:----:----:----:----:--
!1234567890   12345678901
 2010 FORMAT(10X,I3,12X,I3,13X,I2,10X,I3,10X,I3)
!
      WRITE(STDOUT,*) ' INPUT FILE =',INFILE
      WRITE(STDOUT,*) ' OUTPUT GRID TYPE =',KGRID
!
!     GET INDEX FILE FROM WGRIB
!
      CLOSE(UNIT=LCNTRL2)
      KLENIN=LEN_TRIM(INFILE)
!
! Where is 'ywgrib' on the system?  Get path/command from calling script:
      call getenv("YWGRIB",YWGRIB)
      kyw=len_trim(YWGRIB)
!
      CMD=YWGRIB(1:kyw)//' '//infile(1:klenin)//' >outfile.ywgrib'
      lencmd=len_trim(CMD)
!test
      write(6,*) 'CMD=', CMD(1:lencmd)
!test
!
#ifdef XLF
! Use this for XLF Fortran:
      CALL SYSTEM(CMD(1:lencmd),IER)
#else
! Use this for Intel Fortran:
      IER=SYSTEM(CMD(1:lencmd))
#endif
!
      OPEN(UNIT=LCNTRL2,FILE='outfile.ywgrib')
!
! Format of ywgrib output, from 
!   /com/nam/prod/ndas.20070501/ndas.t00z.egrdsf03.tm12
! (No. 49 is precip, no. 51 is LSPA):
!
!  49   2 255  61 200704301200   0   3   4     sfc min/max         0     104.5
!
!  51 130 255 154 200704301200   0   3   4     sfc min/max         0     104.5
!
!----:----|----:----|----:----|----:----|----:----|----:----|----:----|----:--
!
! Read through each record in the ywgrib output:
 20   continue
      read(LCNTRL2,2040,end=100) nrec,itable,igrid,iparm,idate,ip1,ip2
      write(6,2040)  nrec,itable,igrid,iparm,idate,ip1,ip2
 2040 format(i4,x,i3,x,i3,x,i3,x,i10,2x,2(1x,i3))
!
! Check the PDS of the current record against the input card.  Do we want
! to extract this record?
!
      if (nrec.eq.48) then
         write(6,*) 'jpds5,iparm=',jpds5,iparm
         write(6,*) 'jpds14,ip1=',jpds14,ip1
         write(6,*) 'jpds15,ip2=',jpds15,ip2
         write(6,*) 'kgrid,igrid=',kgrid,igrid
         write(6,*) 'jpds19,itable=',jpds19,itable
      endif

      IF ((JPDS5.EQ.iparm.OR.JPDS5.EQ.-1).AND.                                &
          (JPDS14.EQ.ip1.OR.JPDS14.EQ.-1).AND.                                &
          (JPDS15.EQ.ip2.OR.JPDS15.EQ.-1).AND.                                &
          (KGRID.EQ.igrid .OR. KGRID.EQ.0 .OR. KGRID.EQ.-1).AND.              &
          JPDS19.EQ.itable) THEN
        KLENOUT=LEN_TRIM(OUTFILE)
        write(6,*) 'OUTFILE=', outfile
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
! This is what 'CMD' should look like (paths omitted for clarity), to
! get the 4th record from SREF emsemble mean file mean.f09z.f57:
!
!   wgrib mean.t09z.f57 | egrep "(^4:)" | wgrib -i mean.t09z.f57 \\
!    -grib -o /ptmp/wx22yl/verif/archive/20030601/srmean_2003060109_033_057
!
        call getenv("WGRIBpath",WGRIBpath)
        kpath=len_trim(WGRIBpath)
        CMD=WGRIBpath(1:kpath)                                                &
     &    //'/wgrib '                                                         &
     &    // INFILE(1:klenin)                                                 &
     &    // ' | egrep "(^'                                                   &
     &    // crec(1:ni)                                                       &
     &    // ':)" | '                                                         &
     &    // WGRIBpath(1:kpath)                                               &
     &    // '/wgrib -i '                                                     &
     &    // INFILE(1:klenin)                                                 &
     &    // ' -grib -o '                                                     &
     &    // OUTFILE(1:klenout)                                                
        lencmd=len_trim(CMD)
!
#ifdef XLF
! Use this for XLF Fortran:
        CALL SYSTEM(CMD(1:lencmd),IER)
#else
! Use this for Intel Fortran:
        IER=SYSTEM(CMD(1:lencmd))
#endif
!
      ENDIF
!
!   TRY NEXT RECORD in the wwgrib output:
!
      GOTO 20

 100  CONTINUE
!   Read the next brkout request from the control file:
      GOTO 10
!     
!     END OF PROGRAM
!     
 9999 STOP
      END
