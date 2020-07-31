      program addgrdcnv
!
!$$$  MAIN PROGRAM DOCUMENTATION BLOCK
!                .      .    .                                       .
! MAIN PROGRAM: ACCPPT
!  
!   Programmer: Ying lin           ORG: NP22        Date: 2011-08-12
!
! ABSTRACT: program to read in a gridscale and a convective precip file, 
!   add them up and output it as total precip.  All file names are read in
!   from unit 5.  GRIB head for output file is from one of the input files,
!   just change the parameter number to 61 (total precip).
! 
! PROGRAM HISTORY LOG:
!
! 2011-08-12 Y. Lin: created program.
! 2012-07-30 Y. Lin: Convert to ifort for Zeus/WCOSS
!!
!    Unit 5 input cards:
!     ----:----|----:----|
!  1. rucg_2011081203_003_006   --> Unit 11
!  2. rucc_2011081203_003_006   --> Unit 12
!  3. ruc_2011081203_003_006    --> Unit 51
!
! ATTRIBUTES:
!   LANGUAGE: Intel FORTRAN 90
!   MACHINE : Zeus/WCOSS
!
!$$$
      integer jpds(200),jgds(200),kpds(200),kgds(200)
      integer kpdso(200),kgdso(200)
      parameter(ji=5000000)
      logical*1 bittot(ji),bit(ji), aok
      real ptot(ji),p(ji)
      character*160 finput(2), foutput
!
        iunit=0
        iacc=0
        i = 0
        sum=0.
!
!    Read the flag indicating what kind of time stamp to use in output file
!    names (i.e. whether we are dealing with model output or observations)
!
        read(5,'(a160)') finput(1)
        read(5,'(a160)') finput(2)
        read(5,'(a160)') foutput
 10     format(a3,x,a2)
!
      ptot=0.
      bittot=.true.
      aok=.true.
!
      do 100 n = 1, 2       
        iunit=10+n
        jpds=-1
        jgds=-1
!
        call baopenr(iunit,finput(n),ierrba)
        call getgb(iunit,0,ji,0,jpds,jgds,kf,kr,kpds,kgds,bit,p,iret)
        write(6,*) 'getgb ', finput(n), ' iretba, iret=', iretba, iret,       &
           ' kf=', kf
        call baclose(iunit,ierr)
!
!   sum up, write out
!
        if (iretba.eq.0 .and. iret.eq.0 .and. aok) then
          aok=.true.

          do i = 1, kf
            if (bit(i) .and. bittot(i)) ptot(i) = ptot(i) + p(i)
            bittot(i) = bit(i)
          enddo
        else
          aok=.false.
        endif
 100  continue ! finished reading both gridscale and conv precip
!
      if ( aok ) then
        kpds(5)=61
        call baopen(51,foutput,ierr)
        call putgb(51,kf,kpds,kgds,bittot,ptot,iret)
        if (iret.eq.0) then
          write(6,*) 'PUTGB successful, iret=', iret
        else
          write(6,*) 'PUTGB failed!  iret=', iret
        endif
        CALL BACLOSE(51,ierr)
      endif

      CALL W3TAGE('ACCPCP ')
      stop
      end
