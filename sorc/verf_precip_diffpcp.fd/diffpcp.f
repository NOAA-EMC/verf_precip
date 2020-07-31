      program diffpcp
!
!$$$  MAIN PROGRAM DOCUMENTATION BLOCK
!                .      .    .                                       .
! MAIN PROGRAM: DIFFPPT
!  
!   Programmer: Ying lin           ORG: NP22        Date: 2002-07-26
!
! ABSTRACT: program to read in two precip files, then subtract the 
! amount in file #2 from that in file #2.  Useful when the precip files
! we receive from outside are like that from UKMO, where instead of
! emptying the bucket periodically, they just keep adding to it, and
! we get amounts for 00-12h, 00-24h, ..., 00-72h.  
! 
! The program assumes that the two grib files have the same time stamp
! [PDS(8-12), PDS(21)], and the same PDS(14) (time range 1 - starting
! bucket time).  Only PDS(15) (time range 2 - ending time of the
! bucket) is different.  The difference file will have the same
! time stamp, PDS(15) of infile2, and PDS(14) that is the PDS(15) of
! infile1.  E.g.
!
! nam_2007060712_024_027  ! Input #1
! nam_2007060712_024_030  ! Input #2
! 
! nam_2007060712_027_030  ! output file
!
! This program requires an "input card" read in from Unit 6.  The Input card
! has four lines, like this:
!    timeflag  (=mod or obs: see notes below)
!    mod_      (prefix of output file)
!    mod_yyyymmddhh_$hr1_$hr2
!    mod_yyyymmddhh_$hr1_$hr3
! 
! Note about timeflag (character*3):
!        timeflag='mod' or 'MOD': time stamp in output file name is
!                  the model forecast cycle, e.g., 2001071912_12_24, followed
!                  by forecasting periods (here it means 12-24h forecast for
!                  the 12Z 19 Jul model cycle).  Used in dealing with model 
!                  forecasts (e.g. for precip verif)
!        timeflag='obs' or 'OBS': time stamp in output file name is
!                  the ending time of the observation period, followed
!                  by the length of the observation period.  e.g.,
!                  pcp2001071912.06 (precip accum during 06-12Z, 19 Jul 2001)
!
! PROGRAM HISTORY LOG:
! 
! 2002/07/26  This program was created based on the 'precip accum' program.
!
! 2004/9/22
!   Changed unit decimal scale factor from 1 to 2 (accuracy from 0.1mm 
!    to 0.01mm)
!
! 2007/6/8 YLIN
!   Changed forecast hours from 2-digit to 3-digit
!
! 2010/8/24 YLIN
!   Increased maximum array size (ji) from 1200x900 tp 1800x900, to 
!   accommodate the increased size of GFS precipitation array.  Cleaned up
!   the docblock and program history - the original doc/history contained
!   some vestige of doc/history from the precip accumulation program.  
!
! 2012-07-23  Y. Lin:  Convert to ifort for Zeus/WCOSS
!
!    Unit 5 input cards:
! Sample input card:
! ----:----|----:----|----:----|
! mod                    ! model precip - time stamp is the start of accum time
! nam__                  ! output file prefix
! nam_2007060712_024_027 ! Input #1
! nam_2007060712_024_030 ! Input #2
!
! ATTRIBUTES:
!   LANGUAGE: Intel FORTRAN 90
!   MACHINE : Zeus/WCOSS
!
!$$$
      integer jpds(200),jgds(200),kpds1(200),kpds2(200),kgds(200)
      integer kpdso(200),kgdso(200)
      parameter(ji=5000*2000)
      logical*1 bitdiff(ji),bit1(ji),bit2(ji)
      real diff(ji),pcp1(ji), pcp2(ji)
      character*200 infile1,infile2,prefx,outfile
      character*18 datstr
      character*3 timeflag
      character*2 orflag
      INTEGER IDAT(8),JDAT(8)
      REAL RINC(5)
!
!    Read the flag indicating what kind of time stamp to use in output file
!    names (i.e. whether we are dealing with model output or observations)
!
      read(5,10) timeflag
 10   format(a3,x,a2)
!
!
!    read output file name prefix
!
      read(5,20) prefx
      kdatp=index(prefx,' ')-1
      if (kdatp.le.0) kdatp=len(prefx)
!
!    read input file name
!
      read(5,20,end=999) infile1
      read(5,20,end=999) infile2
 20   format(a200)

      jpds=-1
      jgds=-1
!
!   Get precip.  ETA and most others have pds(5)=61, but AVN and MRF
!   have pds(5)=59 (precip rates), and in those cases we should 
!   add up the files and then divde the result by the number of files
!   that contributed to the sum (i.e. calculate the average precip rate
!   during the entire period
!
      call baopenr(11,infile1,ierr)
      call getgb(11,0,ji,0,jpds,jgds,kf1,kr,kpds1,kgds,bit1,pcp1,iret1)
      write(6,*) 'getgb ', infile1, 'kf1= ',kf1, '  iret=', iret1
!
      call baopenr(12,infile2,ierr)
      call getgb(12,0,ji,0,jpds,jgds,kf2,kr,kpds2,kgds,bit2,pcp2,iret2)
      write(6,*) 'getgb ', infile2, 'kf2= ',kf2, ' iret=', iret2
!
!   Calculate the difference (subtract file1 from file2):
!
      if (iret1.ne.0 .or. iret2.ne.0)                                         &
          STOP 'iret1 and/or iret2 not zero!'

!
! Check to see if the two files have the same length:
      if (kf1.ne.kf2)                                                         &
          STOP 'File lengths (kf1,kf2) differ!  STOP.'
!
! Check to see if the two time stamps are identical:
      if (kpds1(21).ne.kpds2(21) .or. kpds1( 8).ne.kpds2( 8) .or.             &
          kpds1( 9).ne.kpds2( 9) .or. kpds1(10).ne.kpds2(10) .or.             &
          kpds1(11).ne.kpds2(11) .or. kpds1(12).ne.kpds2(12) .or.             &
          kpds1(13).ne.kpds2(13)) then
        write(6,30)                                                           &
         (kpds1(21)*100+kpds1(8))/100-1, mod(kpds1(8),100),                   &
          kpds1(9),kpds1(10),kpds1(11),kpds1(12),kpds1(13),                   &
         (kpds2(21)*100+kpds2(8))/100-1, mod(kpds2(8),100),                   &
          kpds2(9),kpds2(10),kpds2(11),kpds2(12),kpds2(13)
 30     format('Time stamps differ! Date1=',7i2.2,' Date2=',7i2.2, '  STOP')
        stop
      endif
!
! Check to see if the two 'time range 1' are identical:
      if (kpds1(14).ne.kpds2(14)) then
        write(6,*) 'Time range 1 differ: kpds1(14)=', kpds1(14),              &
          ' kpds2(14)=', kpds2(14),'  STOP'
        stop
      endif
!
! Check 'time range 2' to make sure that kpds2(15) > kpds1(15):
!
      if (kpds1(15).ge.kpds2(15)) then
        write(6,*) 'Time range 2 problem: kpds1(15)=', kpds1(15),             &
          ' kpds2(15)=', kpds2(15),'  STOP'
        stop
      endif
!
      kpdso=kpds2
      kgdso=kgds
!
      kpdso(14) = kpds1(15)
!

      do 40 N=1,kf1
        bitdiff(N)=bit2(N).and.bit1(N)
        if (bitdiff(N)) then
          diff(N)=pcp2(N)-pcp1(N)
          write(54,54) n, diff(n), pcp2(n), pcp1(n)
 54       format(i8,2x,3(3x,f8.3))
        else
          diff(N)=0.
        endif
 40   continue
!
 999  continue
!
! set unit decimal scale factor
      kpdso(22) = 1
!
! set output time stamp. For 'mod/MOD', time stamp is forecast zero time.
! For 'obs/OBS', time stamp is the end of accumulation time.
!
      if (timeflag.eq.'mod' .or. timeflag.eq.'MOD') then
         WRITE(DATSTR,50) (KPDSO(21)-1)*100+KPDSO(8),KPDSO(9),                &
           KPDSO(10),KPDSO(11),KPDSO(14),KPDSO(15)
 50      FORMAT(I4.4,3I2.2,'_',I3.3,'_',I3.3)
      else
         idat(1)=(KPDSO(21)-1)*100+KPDSO(8)
         idat(2)=KPDSO(9)
         idat(3)=KPDSO(10)
         idat(5)=KPDSO(11)
         rinc= 0.
         if (kpdso(13).eq.1) then
           rinc(2)=KPDSO(15)
         elseif (kpdso(13).eq.2) then
           rinc(2)=KPDSO(15)*24
         endif
         CALL W3MOVDAT(RINC,IDAT,JDAT)
         write(datstr,60) jdat(1),jdat(2),jdat(3),jdat(5)
 60      format(i4.4,3i2.2,'.')
         if (kpdso(15).lt.100) then
           if (kpdso(13).eq.1) then 
             write(datstr(12:15),70) kpdso(15), 'h'
           elseif (kpdso(13).eq.2) then 
             write(datstr(12:15),70) kpdso(15), 'd'
           endif
 70        format(i2.2,a1)
         else
           if (kpdso(13).eq.1) then 
             write(datstr(12:16),80) kpdso(15), 'h'
           elseif (kpdso(13).eq.2) then
             write(datstr(12:16),80) kpdso(15), 'd'
           endif
 80        format(i3.3,a1)
         endif
      endif
!
      OUTFILE = PREFX(1:KDATP) // DATSTR
      CALL BAOPEN(51,OUTFILE,ierr)
      call putgb(51,kf1,kpdso,kgdso,bitdiff,diff,iret)
      if (iret.eq.0) then
        write(6,*) 'PUTGB successful, iret=', iret, 'for ', outfile
      else
        write(6,*) 'PUTGB failed!  iret=', iret, 'for ', outfile
      endif
      CALL BACLOSE(51,ierr)
      CALL W3TAGE('DIFFPCP ')
!
      stop
      end
