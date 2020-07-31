      program accppt
!
!$$$  MAIN PROGRAM DOCUMENTATION BLOCK
!                .      .    .                                       .
! MAIN PROGRAM: ACCPPT
!  
!   Programmer: Ying lin           ORG: NP22        Date: 2002-05-31
!
! ABSTRACT: program to read in a set of precip files, add them up and
!   write out the total precip
! 
! PROGRAM HISTORY LOG:
!
!  1/14/00  MEB
!    program to read in a set of precip files, add them up
!    and write out the total precip for verf 
!    (for the multi-sensor to make 3h precip)
!  
! 2001/3/19 YL: difference from the MB version:
!    print out error flag after getgb
! 2001/6/28
!    set decimal scale factor (kpds(22)) to 1, so the output would be
!    accurate to 0.1mm (otherwise it'll be 1mm!).  The original eta output
!    has  'BinScale -3' (max data  65.375 - from wgrib), I guess it means
!    it's accurate to 1/8=0.125mm, but it's not passed on to PDS.
! 2001/7/19
!    Add timeflag (character*3).  
!        timeflag='mod' or 'MOD': time stamp in output file name is
!                  the model forecast cycle, e.g., 2001071912_12_24, followed
!                  by forecasting periods (here it means 12-24h forecast for
!                  the 12Z 19 Jul model cycle).  Used in dealing with model 
!                  forecasts (e.g. for precip verif)
!        timeflag='obs' or 'OBS': time stamp in output file name is
!                  the ending time of the observation period, followed
!                  by the length of the observation period.  e.g.,
!                  pcp2001071912.06 (precip accum during 06-12Z, 19 Jul 2001)
!    Add 'orflag' (character*2) (combine MB's acc.f and acc_or.f)
!         orflag='or'/'OR': for any given point, if at least one hour has
!                 value, this point is considered valid.  Only intended
!                 for plotting.  
! 2002/5/31
!    If accumulation is for more than 255 hours, switch time unit to 'day'.
!    Output file name for this is only set up correctly for 'obs'.
!
! 2002/8/12
!    The earlier versions of acc.f took into account of various non-61
!    rain parameters (e.g. rain rate '59' in AVN and MRF, various others
!    in international models).  Since I have decided, for verification
!    purposes, to use a pre-processor to convert the various model 
!    precip forecast to precip accumulation,  this subroutine is now
!    reverted to dealing with parameter 61 only.
!
! 2012-07-23  Y. Lin:      - Convert to ifort for Zeus/WCOSS
!
!    Unit 5 input cards:
!     ----:----|----:----|
!  1. OBS OR              (or 'OBS', or 'MOD'.  the 'or' flag is optional
!  2. ST2ml
!  3. ST2ml2001082807.Grb
!  4. ST2ml2001082808.Grb
!  5. ST2ml2001082809.Grb
!  6. ST2ml2001082810.Grb
!  7. ST2ml2001082811.Grb
!  8. ST2ml2001082812.Grb
!
! ATTRIBUTES:
!   LANGUAGE: Intel FORTRAN 90
!   MACHINE : Zeus/WCOSS
!
!$$$
      integer jpds(200),jgds(200),kpds(200),kgds(200)
      integer kpdso(200),kgdso(200)
      parameter(ji=5000*2000)
      logical*1 lisum(ji),li(ji),aok
      real sum(ji),pcp1(ji)
      character*200 fname,prefx,filnam
      character*18 datstr
      character*3 timeflag
      character*2 orflag
      INTEGER IDAT(8),JDAT(8)
      REAL RINC(5)
!
        iunit=0
        iacc=0
        i = 0
        sum=0.
        aok=.true.
!
!    Read the flag indicating what kind of time stamp to use in output file
!    names (i.e. whether we are dealing with model output or observations)
!
        read(5,10) timeflag, orflag
 10     format(a3,x,a2)
!
      if (orflag.eq.'or' .or. orflag.eq.'OR') then
         lisum=.false.
      else
         lisum=.true.
      endif
!
!    read output file name prefix
!
        read(5,80) prefx
        kdatp=index(prefx,' ')-1
        if (kdatp.le.0) kdatp=len(prefx)
!
!    read input file name
!
        read(5,80,end=999) fname
 80     format(a200)

       do while(fname.ne.'done')
        i=i+1
        iunit=i+12
        jpds=-1
        jgds=-1
!
        call baopenr(iunit,fname,ierr)
        call getgb(iunit,0,ji,0,jpds,jgds,kf,kr,kpds,kgds,li,pcp1,irets)
        write(6,*) 'getgb ', fname, ' irets=', irets
        call baclose(iunit,ierr)
!
!   sum up, write out
!
        if (irets.eq.0) then
          if (i.eq.1) then
!   assume files are in chronological order, first file will
!   have needed date info
           kpdso=kpds
           kgdso=kgds
          endif
          iacc=iacc+kpds(15)-kpds(14)
          DO N=1,kf
           sum(N)=sum(N)+pcp1(N)
           if (orflag.eq.'or' .or. orflag.eq.'OR') then
             lisum(N)=lisum(N).or.li(N)
           else
             lisum(N)=lisum(N).and.li(N)
           endif
          ENDDO
        endif
        read(5,80,end=999) fname
        if (irets.ne.0) then
         fname='done'
         aok=.false.
        endif
        enddo
 999    continue
!
        do n=1,kf
          if (.not.lisum(n)) sum(n)=0.
        enddo
!
        if (aok) then
          KPDSo(15)=kpdso(14)+iacc
          if (iacc.gt.255) then
            if (kpds(13).eq.1) then
              KPDSo(13) = 2
              KPDSo(15) = KPDSo(15)/24
            else
              write(6,*) 'accum more than 255 units, and not hour!'
              stop
            endif
          endif
! set unit decimal scale factor
          kpdso(22) = 1
!
! set output time stamp:
!
          if (timeflag.eq.'mod' .or. timeflag.eq.'MOD') then
            WRITE(DATSTR,4459) (KPDSO(21)-1)*100+KPDSO(8),KPDSO(9),           &
              KPDSO(10),KPDSO(11),KPDSO(14),KPDSO(15)
 4459       FORMAT(I4.4,3I2.2,'_',I3.3,'_',I3.3)
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
            write(datstr,4460) jdat(1),jdat(2),jdat(3),jdat(5)
 4460       format(i4.4,3i2.2,'.')
            if (kpdso(15).lt.100) then
              if (kpdso(13).eq.1) then 
                write(datstr(12:15),4461) kpdso(15), 'h'
              elseif (kpdso(13).eq.2) then 
                write(datstr(12:15),4461) kpdso(15), 'd'
              endif
 4461         format(i2.2,a1)
            else
              if (kpdso(13).eq.1) then 
                write(datstr(12:16),4462) kpdso(15), 'h'
              elseif (kpdso(13).eq.2) then
                write(datstr(12:16),4462) kpdso(15), 'd'
              endif
 4462         format(i3.3,a1)
            endif
          endif
          FILNAM = PREFX(1:KDATP) // DATSTR
          CALL BAOPEN(51,FILNAM,ierr)
          call putgb(51,kf,kpdso,kgdso,lisum,sum,iret)
          if (iret.eq.0) then
            write(6,*) 'PUTGB successful, iret=', iret, 'for ', FILNAM
          else
            write(6,*) 'PUTGB failed!  iret=', iret, 'for ', FILNAM
          endif
          CALL BACLOSE(51,ierr)
        endif
      CALL W3TAGE('ACCPCP ')
      stop
      end
