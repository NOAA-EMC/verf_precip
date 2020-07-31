      program average
!
!$$$  MAIN PROGRAM DOCUMENTATION BLOCK
!                .      .    .                                       .
! MAIN PROGRAM: AVERAGE
!  
!   Programmer: Ying lin           ORG: NP22        Date: 2004-06-10
!
! ABSTRACT: program to read in a set of model precip files 
! (with the same time info); write out the average precip
!
! Usage: compute ensemble mean from members
! 
! PROGRAM HISTORY LOG:
!
!  2004/06/10  YL created
!  2012-07-23  Y. Lin:  Convert to ifort for Zeus/WCOSS
!
!    Unit 5 input cards:
!     ----:----|----:----|
!   w4ip_2003020106_39_42
!   wrfw-8km-mass-rucn-pcar_2003020106_39_42
!   wrfw-8km-mass-rucp-pcar_2003020106_39_42
!   wrfw-8km-nmm-etan-pcep_2003020106_39_42
!   wrfw-8km-nmm-etap-pcep_2003020106_39_42
!
! ATTRIBUTES:
!   LANGUAGE: Intel FORTRAN 90
!   MACHINE : Zeus/WCOSS
!
!$$$
      integer jpds(200),jgds(200),kpds(200),kgds(200)
      integer kpds0(200),kgds0(200)
      parameter(ji=1200*900)
      logical*1 avgbit(ji),bit(ji)
      real pcp(ji),avgpcp(ji)
      character*200 infile,outfile
      REAL RINC(5)
!
      iunit=0
      ninputf=0
      avgpcp=0.
      avgbit=.true.
!
! Read output file name
!
      read(5,'(a200)') outfile
!
! Looping through input files
 10   continue
!
! read input file name
!
      read(5,'(a200)',end=999) infile
!
      iunit=ninputf+12
      jpds=-1
      jgds=-1
!
      call baopenr(iunit,infile,ierr)
      call getgb(iunit,0,ji,0,jpds,jgds,kf,kr,kpds,kgds,bit,pcp,iret)
      write(6,*) 'getgb ', infile, ' iret=', iret
      call baclose(iunit,ierr)
!
! sum up, write out
!
      if (iret.ne.0) then
        write(6,*) 'getgb error, STOP'
        stop
      else
        ninputf=ninputf + 1
        do 20 i = 1, kf
          if (bit(i) .and. avgbit(i)) then
            avgpcp(i)=avgpcp(i)+pcp(i)
          else
            avgbit(i)=.false.
          endif
 20    continue
      endif
!
! first file will have the needed PDS and GDS, and all subsequent files should
! have the same PDS and GDS (in theory).  However, when testing this code, I
! find that FSL WRF runs have inconsistent kpds(4) [the GDS/BMS flag]:
!   wrfw-8km-mass-rucn-pcar_2003020106_39_42 has kpds(4)=192
!   wrfw-8km-nmm-etan-pcep_2003020106_39_42  has kpds(4)=128
! So only check the kpds(8-21) for now, that'll make sure the date/time info
! are consistent
!
! 2005/9/29: don't check PDS(16).  That's the time range indicator. 
!    model    PDS(16) value   meaning
!     NAM          4          accumulation from P1 to P2
!     DWD          5          difference between P2 and P1
! (have not checked this for all models)
! DWD doesn't normally go through pcpconform (il est pret a verifier).  
! It's not worth putting a file through pcpconform just to change the time 
! range indicator.  
! 
! Also exclude PDS(17-20) - version of table etc.  
!
      if (ninputf.eq.1) then
        kpds0=kpds
        kgds0=kgds
      else
        do 30 i = 8, 21
          if (i.ge.16 .or. i.le.21) go to 30
          if (kpds(i).ne.kpds0(i)) then
            write(6,*) 'Inconsistent PDS. STOP'
            write(6,*) 'i/kpds/kpds0=',i, kpds(i), kpds0(i)
            stop
          endif
 30     continue
      endif
!
      go to 10

 999  continue
!
      do 40 i = 1, kf
        if (avgbit(i)) avgpcp(i) = avgpcp(i)/float(ninputf)
 40   continue
!
! Set flag for GDS/BMS to 'GDS and BMS included'.  Some model precip files
! we receive do not have bitmap turned on, some do (e.g. CMC, the file we
! get cover limited areas).  We need to include the bitmap.
!
      KPDS0(4)=192
      CALL BAOPEN(51,outfile,ierr)
      call putgb(51,kf,kpds0,kgds0,avgbit,avgpcp,iret)
      if (iret.eq.0) then
        write(6,*) 'PUTGB successful, iret=', iret
      else
        write(6,*) 'PUTGB failed!  iret=', iret
      endif
      CALL BACLOSE(51,ierr)
      CALL W3TAGE('AVERAGE')
      stop
      end
