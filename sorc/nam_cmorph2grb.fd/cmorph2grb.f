      program cmorph2grb
!$$$  MAIN PROGRAM DOCUMENTATION BLOCK
!                .      .    .                                       .
! MAIN PROGRAM: CMORPH2GRB
!   Read in two consecutive 3-hourly, 1/4 deg CMORPH files (one file per day, 
!   covering 00-23:55UTC).  Make 12Z-12Z sum.  Convert from binary to GRIB.
!  
!   PRGMMR: LIN              ORG: NP2         DATE: 2011/05/16
!
! Missing data in binary file denoted by a value of -9999.
!
! PROGRAM HISTORY LOG:
!   2011/05/16  YING LIN program based on the bin-to-grb conversion code for
!                        the CPC 1/8 deg daily gauge analysis (and the earlier
!                        version of the 'cmorph2grb' code, where a single
!                        daily (00-00Z) record is read in and GRIB'd).
!
!   2014/12/29  Y Lin Modify for new format at CPC. 
!     From ftp://ftp.cpc.ncep.noaa.gov/precip/global_CMORPH/3-hourly_025deg
!               /NOTICE-OF-TEMINATION-OF-THESE-CMORPH-DATA-LOCATIONS
!        * Data will now be oriented from south to north, not
!          north to south (as in the /precip/global_CMORPH version)
!        * Data will be in real*4 little endian binary, not
!          big endian binary (as in the /precip/global_CMORPH version)
!
! USAGE:
!   INPUT FILES:
!     fort.11 - Starting time of 24h accumulation ${vdaym1}00 (e.g.20110513)
!     fort.21 - 20110513_3hr-025deg_cpc+comb
!     fort.22 - 20110514_3hr-025deg_cpc+comb
!   OUTPUT FILES:
!     fort.51  - cmorph.2011051412.grb
!
!   SUBPROGRAMS CALLED: 
!     LIBRARY:  BAOPEN PUTGB W3TAGB  W3TAGE
!
!   EXIT STATES:
!     COND =   0 - SUCCESSFUL RUN
!          =  98 - UNEXPECTED END-OF-FILE ON UNIT 11
! 
! ATTRIBUTES:
!   LANGUAGE:  FORTRAN 90
!   MACHINE:   IBM SP
!
!$$$
!
      parameter(nx=1440,ny=480)
! Co-ord of 'lower-left corner' [i.e. (1,480) point]:
      parameter(alat1=-59.875, alon1=-0.125, ainc=0.25)
!  xpnmcaf, ypnmcaf - location of pole.
!  xmeshl - grid mesh length at 60N in km
!  orient - the orientation west longitude of the grid.
!
      dimension KPDS(25),KGDS(22)
      real*4 dummy(nx,ny), cmorph(nx,ny)
      logical*1 bitmap(nx,ny)
!
! Read in the starting date of the accumulation to idat1.  Advance it by
! 1 day (rinc), store the info in idat2.  
!     idat(1)=yyyy; idat(2)=mm, idat(3)=dd, idat(5)=hh
      integer idat1(8), idat2(8), fhr
      real rinc(5)
      rinc=0.
      rinc(1)=1.
!
!  Keep track of cmorph file read error(s).  We do this instead of 'exit upon
!  first error', so that we might have some idea of where the file is short.
      nerr=0
!
      CALL W3TAGB('CMORPH2GRB',1998,0313,0072,'NP2    ')                  
!--------------------------------------------------------------------
!    
!  Compute the (lat,lon) of upper-right corner of the domain:
!
      alon2=alon1 + (nx-1)*ainc
      alat2=alat1 + (ny-1)*ainc
!
!     read(11,'(i4,3i2)',end=9998) iyear, imo, ida, ihr
      read(11,'(i4,3i2)',end=9998) idat1(1),idat1(2),idat1(3),idat1(5)
      open(21,access='direct',recl=1440*480*4,form='unformatted')
      open(22,access='direct',recl=1440*480*4,form='unformatted')
!
! Read in record 5, 6, 7, 8 (12-15,15-18,18-21,21-00Z) from file 1, then 
! read in record 1, 2, 3, 4 (00-03,03-06,06-09,09-12Z) from file 2:
      cmorph=0.
      bitmap=.true.
!
      do 50 nfile=1, 2
        write(6,*) 'loop 50, nfile=', nfile
        if (nfile .eq. 1) then
          nrbeg=5
          nrend=8
        else
          nrbeg=1
          nrend=4
        endif
!
        do 40 nrec=nrbeg, nrend
        write(6,*) '   loop 40, nrec=', nrec
          read(20+nfile,rec=nrec,err=9995) dummy
!
          do 20 j = 1, ny
            do 10 i = 1, nx
              if (bitmap(i,j) .and. dummy(i,j).ge.0.) then
                cmorph(i,j)=cmorph(i,j)+dummy(i,j)
              else
                bitmap(i,j)=.false.
              endif
 10         continue ! i
 20       continue   ! j
!
          go to 40
 9995     write(6,*) 'CMORPH read error, file', nfile, ' record', nrec
          nerr=nerr+1
!
 40     continue ! nrec
 50   continue   ! nfile
!
      KPDS(1) =7     ! Generating center: NCEP
      KPDS(2) =0     ! Generating Process: no number defined in grib manual
      KPDS(3) =255   ! Grid definition: undefined 
      KPDS(4) =192   ! GDS/BMS flag (right adj copy of octet 8)
      KPDS(5) =61    ! Parameter type
      KPDS(6) =1     ! Type of level
      KPDS(7) =0     ! Height/pressure , etc of level
      KPDS(8) =mod(idat1(1)-1,100)+1  ! 2-digit year
      KPDS(9) =idat1(2)   ! Month
      KPDS(10)=idat1(3)   ! Day
      KPDS(11)=idat1(5)   ! Hour
      KPDS(12)=0     ! Minute
      KPDS(13)=1     ! Indicator of forecast time unit
      KPDS(14)=0     ! Time range 1
      KPDS(15)=24    ! Time range 2 (time interval)
      KPDS(16)=4     ! Time range flag
      KPDS(17)=0     ! Number included in average
      KPDS(18)=1     ! Version nr of grib specification
      KPDS(19)=2     ! Version nr of parameter table
      KPDS(20)=0     ! NR missing from average/accumulation
      KPDS(21)=(idat1(1)-1)/100 + 1 ! Centery
      KPDS(22)=2     ! Units decimal scale factor
      KPDS(23)=4     ! Subcenter number (EMC)
      KPDS(24)=0     ! PDS byte 29, for nmc ensemble products
      KPDS(25)=0     ! PDS byte 30, not used
!
      KGDS(1)= 0     ! Data representation type (lat/lon)
      KGDS(2)= nx    ! Number of points on latitude circle
      KGDS(3)= ny    ! Number of points on longitude meridian
      KGDS(4)= 1000.*alat1 ! latitude of origin
      KGDS(5)= 1000.*alon1 ! Longitude of origin
      KGDS(6)= 128     ! Resolution flag (right adj copy of octet 17)
      KGDS(7)= 1000.*alat2   ! latitude of extreme point
      KGDS(8)= 1000.*alon2  ! longitude of extreme point
      KGDS(9)= 1000.*ainc    ! longitudinal direction of increment
      KGDS(10)= 1000.*ainc   ! latitudinal direction of increment
      KGDS(11)= 64           ! scanning mode flag (right adj copy of octet 28)
      KGDS(12)= 0
      KGDS(13)= 0
      KGDS(14)= 0
      KGDS(15)= 0
      KGDS(16)= 0
      KGDS(17)= 0
      KGDS(18)= 0
      KGDS(19)= 0
      KGDS(20)= 255
      KGDS(21)= 0
      KGDS(22)= 0
!
!  Output GRIB version of the CMORPH analysis, if there hasn't been any
!  read error(s)
!
      if (nerr .eq. 0) then
        call baopen(51,'fort.51',iretba)
        call putgb(51,nx*ny,kpds,kgds,bitmap,cmorph,iret)
        write(6,*) 'PUTGB to unit 51, iret=', iret,' iretba=', iretba
      else
        write(6,*) 'Total number of CMORPH read errors:', nerr
        CALL W3TAGE('CMORPH2GRB')
        call errexit(99)
      endif
      stop
!
 9998 continue
      write(6,*) 'Unexpected end-of-file on unit 11'
      CALL W3TAGE('CMORPH2GRB')
      call errexit(98)
!
      end
