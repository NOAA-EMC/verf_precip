PROGRAM Fractional_Skill_Scores
!
! Purpose: Computing Fractional Skill Scores
!
! INPUT FILES:
!   Unit 11 forecast precip
!   Unit 12 observed precip (i.e. verifying analysis)
!   Unit 13 verifying domain mask
! OUTPUT FILE:
!   UNIT 51 VSDB output
!
! Record of revisions:
!    Date      Programmer     Description of Change
!   ========   ==========     =================================================
!   20090311   Ying Lin       Original code
!   20130920   Y Lin          Adapted to WCOSS.  
!                             Verifying analysis: 24h CCPA
!                             Verifying grid: 4km HRAP
!                             Data mask: pcpanl.v*/fix/stage3_mask.grb
!   20150715   Y Lin          Made 6h version
!   20160204   Y Lin          Merged 6h and 24h FSS code
!              diff between 6h and 24h:
!                - APCP/06 vs. APCP/24 in VSDB
!                - different thresholds (still 6 thresholds total)
!                - Maximum horizontal scale: 
!                    31x4.765km=147.715km for 6h; 63x4.765km=300km for 24h
!                         
IMPLICIT NONE

! Dimension of analysis and model file arrays.  Currently use G218:
INTEGER, PARAMETER :: nx = 1121, ny = 881

! Number of precip thresholds to compute FSS:
INTEGER, PARAMETER :: nthresh = 6

! Maximum width (in terms of number of grids for the side of the square) 
! for FSS boxes (FSS is computed for squares that have 3, 5, 7, ... 'maxwidth' 
! number of grids on each side).  This number corresponds to a maximum spatial 
! scale of 300km (cut-off of 300km: maximum grid size we ever used at NCEP/NMC.
! Verif-unif meeting, 7 May 2009).  63x4.765km=300km.
!
! For 6hrly, to save time: 31x4.765km=147.715km

INTEGER, PARAMETER :: maxwidth24 = 63, maxwidth06 = 31

! Forecast and observed precip arrays:
REAL, DIMENSION(nx,ny)    :: p_fcst, p_obs 

! bitmap for model and analysis arrays, and for the 'Stage III byte map'
LOGICAL(KIND=1), DIMENSION(nx,ny) :: bitf, bito, bitm

! Just one verification region for now: CNS (ConUS).  Read in stage3_mask.grb
! from Unit 13.  Later combined with
! with bitf and bito to indicate areas with both valid model and analysis data
REAL,    DIMENSION(nx,ny) :: rfcmask
INTEGER, DIMENSION(nx,ny) ::    mask
INTEGER :: imask  ! nearest integer to rfcmask(i,j), to compare with RFC IDs
INTEGER :: vacc ! length of verification hour (=24 or 06)                   
INTEGER :: maxwidth  ! takes on the value of either maxwidth24 or maxwidth06

! Arrays indicating whether a given grid point exceeds a given threshold value.
!  = 1: exceeds threshold
!  = 0: does not exceed threshold, or not a valid data point (either bitf or
!       bito is false, or if outside verification domain)  
INTEGER, DIMENSION(nx,ny) :: f_exceed, o_exceed

! In each sample square, fractions of predicted/observed grids that exceed 
! the precip threshold:
REAL :: f_frac, o_frac

! The fractional Brier score, mean of squared forecast fractions and mean
! of squared observed fractions:
REAL :: FBS, SUMf, SUMo

! PDS and GDS arrays for 1) forecast 2) analysis (o) and 3) 'getgb' search
INTEGER, DIMENSION(200)   :: pdsf, gdsf, pdso, gdso, jpds, jgds, kpds, kgds

CHARACTER(len=80)         :: infile
CHARACTER(len=3)          :: region   ! verf region: 'CNS'
                                      ! 'WST' or 'EST' deactivated
INTEGER                   :: kf,ko,k,km,ibret, iretm,iretf,ireto ! used in getgb
                                        
! Left and right margins for each row of verifying area that had no data;
! maximum width of verifying area. For more info see the section below
! where this three numbers are computed
INTEGER                   :: marginL, marginR, globalwidth

! VSDB "header" (fixed portion) and the entire VSDB line:
! vsdb0   = V01 NAM 24 2013091812 CCPA G240/CNS FSS<
! vsdbline= V01 NAM 24 2013091812 CCPA G240/CNS FSS<332 APCP/24>25. \
!                               SFC = N FBS SUMf SUMo
!   We use G240 to denote the HRAP grid, even though our definition of the HRAP
!   is half a grid point shifted from the ON388 definition (G255 does not 
!   provide enough info about the grid)
CHARACTER(len=80)  :: vsdb0
CHARACTER(len=160) :: vsdbline

! Format for writing out VSDB file:
CHARACTER(len=6)  :: fmt

! Character string for GETENV:
CHARACTER(len=120) :: string

! Lengths of string, vsdb0 and vsdbline, minus trailing blanks:
INTEGER :: lstring, lvsdb0, lvsdb

! precip thresholds  (in mm)
REAL, DIMENSION(nthresh)  :: pthresh24, pthresh06, pthresh
! In mm:
DATA pthresh24 /2., 5., 10., 15., 25., 50./
DATA pthresh06 /1., 2.,  5., 10., 20., 50./

! DO loop indices:
INTEGER :: i, j, icenter, jcenter, ithresh, nwidth

! Sample square width in KM, rounded up to integer:
INTEGER :: kmwidth

! Search radius: 
INTEGER :: nrad

! Grid size:
REAL :: dx

! Number of "central" grid points examined (for each threshold, and each 
! "search radius":
INTEGER :: N

! Number of valid grid points in each sample box:
INTEGER :: Ncount

! For 'getgb' searches:
jpds = -1 

! Read in verification time length (24h or 06h)
      call getenv("vacc",string)
      read(string(1:2),'(i2)') vacc
!
    IF ( vacc == 24 ) THEN
      pthresh=pthresh24
      maxwidth=maxwidth24
    ELSEIF ( vacc == 06 ) THEN
      pthresh=pthresh06
      maxwidth=maxwidth06
    ELSE
      write(6,*) 'FSS vacc =',vacc, 'is neither 24 nor 6! STOP'
      STOP
    ENDIF
! 
! Read in the 'Stage III bytemap' that maps out the RFC territories:
    call baopenr(13,'fort.13',ibret)
    call getgb(13,0,nx*ny,0,jpds,jgds,km,k,kpds,kgds,bitm,rfcmask,iretm)
    WRITE(*,*) 'Openning RFC mask file', ' ibret=', ibret,                    &
   &        ' iretm=', iretm, ' nx*ny=', nx*ny, ' km=', km

! Read in forecast precip file:
    CALL baopenr(11,'fort.11',ibret)
    CALL getgb(11,0,nx*ny,0,jpds,jgds,kf,k,pdsf,gdsf,bitf,p_fcst,iretf)
    WRITE(*,*) 'Openning forecast pcp file', ' ibret=', ibret,                &
   &        ' iretf=', iretf, ' nx*ny=', nx*ny, ' kf=', kf

! Read in observed (i.e. analysis) precip file:
    CALL baopenr(12,'fort.12',ibret)
    CALL getgb(12,0,nx*ny,0,jpds,jgds,ko,k,pdso,gdso,bito,p_obs,ireto)
    WRITE(*,*) 'Openning analysis pcp file', ' ibret=', ibret,                &
   &        ' ireto=', ireto, ' nx*ny=', nx*ny, ' ko=', ko

!
    IF (iretm/= 0 .OR. iretf /= 0 .OR. ireto /=0) THEN
      WRITE(*,*) 'File read error, STOP. iretm,iretf,ireto=',iretm,iretf,ireto
      STOP
    END IF

! Do the model precip file and the analysis file have the same grid number?
    IF (pdsf(3) /= pdso(3)) THEN
      WRITE(*,*) 'STOP: model and analysis grids are different',              &
   &             ' pdsf(3)/pdso(3)=',pdsf(3), pdso(3)
      STOP
    END IF

! Get grid size (assuming the grid is either Lambert Conformal or polar 
! Stereographic:
    IF (gdsf(1) == 3 .OR. gdsf(1) == 5) THEN
      dx = gdsf(8)/1000.   ! Convert from m to km
    ELSE
      WRITE(*,*) 'GRID is neither Lamb. Conf. nor Polar Stereo. STOP.'
    END IF

! Write out time stamps for model and analysis:
    WRITE(*,10) (pdsf(21)*100+pdsf(8))/100-1, mod(pdsf(8),100),               &
   &    pdsf(9), pdsf(10), pdsf(11), pdsf(14), pdsf(15)
 10 FORMAT('fcst pcp: ', 5i2.2, ' cycle, ', i2.2,'-',i2.2,'h fcst')

    WRITE(*,20) (pdso(21)*100+pdso(8))/100-1, mod(pdso(8),100),               &
   &    pdso(9), pdso(10), pdso(11), pdso(14), pdso(15)
 20 FORMAT('obs pcp: ', 5i2.2, ' cycle, ', i2.2,'-',i2.2,'h accu')

! Get the model name:
    CALL GETENV("MODNAM",string)
    lstring = LEN_TRIM(string)

! 'V01 NAM '
!  ^^^^^^^^
    vsdb0='V01 ' // string(1:lstring)
    lvsdb0=LEN_TRIM(vsdb0)  ! length of vsdb0 so far

! Get the forecast hour:
    CALL GETENV("fhour",string)
    lstring=len_trim(string)

! 'V01 NAM 036 '
!          ^^^
   vsdb0=vsdb0(1:lvsdb0)//' '//string(1:lstring)
   lvsdb0=LEN_TRIM(vsdb0)   ! length of vsdb0 so far
      
! Get the verification time: 
   CALL GETENV("vdate", string)
! 'V01 NAM 036 2009050812'
!             ^^^^^^^^^^
   vsdb0(lvsdb0+2:lvsdb0+11) = string(1:10)
   lvsdb0=LEN_TRIM(vsdb0)

! Get name of verifying analysis (CPCANL, STAGE2, STAGE4 etc.)
!  'V01 NAM 36 2009050812 CCPA G'
!                        ^^^^^^^^^
   CALL GETENV("VERFANL",string)
   lstring=len_trim(string)
   vsdb0 = vsdb0(1:lvsdb0)//' '//string(1:lstring)//' G'
   lvsdb0=LEN_TRIM(vsdb0)

! Add the grid number. 
!  'V01 NAM 36 2009050812 CCPA G240/'
!                              ^^^^
!  WRITE(vsdb0(lvsdb0+1:lvsdb0+4),"(i3.3,'/')") pdsf(3)
!  Hardwire the grid number to '240'.
   vsdb0(lvsdb0+1:lvsdb0+4)='240/'
   lvsdb0=lvsdb0+4

! Get the verifying region:
!  'V01 NAM 036 2009050812 CCPA G240/CNS FSS<'
!                               ^^^^^^^^
   CALL GETENV("region",region)
   vsdb0 = vsdb0(1:lvsdb0)//region//' FSS<'
   lvsdb0=LEN_TRIM(vsdb0)

!
! Simplify the mask: set verifying areas to '1' and outside areas to '0'.
    IF (region == 'CNS') THEN
      DO j = 1, ny
      DO i = 1, nx
!       find the nearest integer to the mask value.  The grid point is within
!       ConUS if imask=150 (ABRFC), or 152, 153, ... 162.  
!       
        imask=nint(rfcmask(i,j))
        IF (imask >= 150 .AND. imask <=162 .AND. imask /= 151) THEN
          mask(i,j) = 1
        ELSE
          mask(i,j) = 0
        END IF

!       Mask out the grid points where either analysis or model value is missing.
        IF (.NOT. (bitf(i,j).AND.bito(i,j))) mask(i,j) = 0
      END DO
      END DO
    ENDIF

! Going through each horizontal row to find the largest dimension of the
!   verifying area:
!
!  00000011110000111111010011000000000000
!  ------                    ------------
!  marginL                      marginR

    globalwidth = 0     ! Largest 'width' of verifying area

    DO 50 j = 1, ny
      marginL=0
      marginR=0

      DO i = 1, nx
        IF (mask(i,j) == 0) THEN
          marginL = marginL + 1
        ELSE
          GO TO 30
        END IF
      END DO
 30   CONTINUE

      DO i = nx, 1, -1
        IF (mask(i,j) == 0) THEN
          marginR = marginR + 1
        ELSE
          GO TO 40
        END IF
      END DO
 40   CONTINUE

      globalwidth = MAX(globalwidth, nx-marginL-marginR)
 50 CONTINUE

      WRITE(*,*) 'globalwidth=', globalwidth

! Give values to f_exceed and o_exceed (0 or 1) depending on whether the grid
! point exceeds the threshold value.
    DO 100 ithresh = 1, nthresh
      f_exceed = 0
      o_exceed = 0

      DO j = 1, ny
      DO i = 1, nx
        IF (mask(i,j) == 1) THEN
          IF (p_fcst(i,j) > pthresh(ithresh)) f_exceed(i,j) = 1
          IF (p_obs(i,j)  > pthresh(ithresh)) o_exceed(i,j) = 1
        END IF
      ENDDO
      ENDDO
!
! Compute fractions for each nwidth (=1,3,5, ... maxwidth)
!
      DO 90 nwidth = 1, maxwidth, 2

! We want to do nwidth = 1, 3, 5, ..., 19, 21, 41, 61, up to maxwidth.
!
        nrad = (nwidth-1)/2  ! search radius, excluding center grid

        FBS = 0.    ! Fractional Brier score
        SUMf = 0.   ! Mean of squared forecast fractions
        SUMo = 0.   ! Mean of squared observed fractions
        
        N = 0
        DO 70 jcenter = 1, ny, 1
          DO 60 icenter = 1, nx, 1

! The center point itself should be a valid grid point:
            IF (mask(icenter,jcenter) == 0) GO TO 60

            f_frac = 0.
            o_frac = 0.
            Ncount = 0
!
! For each sample box, count the number of grid points (in forecast and
! in analysis) that exceed the precip threshold. 
            DO j = jcenter-nrad, jcenter+nrad
              DO i = icenter-nrad, icenter+nrad
                IF (j >= 1 .and. j <= ny .and. i>=1 .and. i<=nx) THEN
                  IF (mask(i,j).eq.1) THEN
                    f_frac = f_frac + f_exceed(i,j)
                    o_frac = o_frac + o_exceed(i,j)
                    Ncount = Ncount + 1
                  END IF
                END IF
              END DO
            END DO

! Was there at least one valid point in the sample box?  If so, add this point
! to the partial sums.
            IF (Ncount > 0) THEN
              N = N + 1
              f_frac = f_frac / float(Ncount)
              o_frac = o_frac / float(Ncount)
              FBS = FBS + (f_frac-o_frac)*(f_frac-o_frac)
              SUMf = SUMf + f_frac*f_frac
              SUMo = SUMo + o_frac*o_frac
            END IF
 60       continue  ! i loop for center points
 70     continue    ! j loop for center points

        FBS = FBS/float(N)
        SUMf = SUMf/float(N)
        SUMo = SUMo/float(N)
! 
! Write out the FVS record:
        vsdbline = vsdb0

! Width of the square (km) is the nearest integer (nnn)
! Threshold is (mm) is nnn.n 
! Both need leading zeros, since we want them to be
!    FSS<037 APCP/24>005.0
! i.e. no empty space between FSS and the width of the square
!    & no empty space between APCP/24> and the threshold value.  
! We're outputting the square width with i3.3
! Threshold is harder, I haven't found a way to output a real number directly
!   with leading zeros.  So what we'll do is to divide each threshold into
!   two parts, output the whole numbers with 'i3.3', and output the fractions
!   after the decimal point with 'f0.1'.
!                  
        kmwidth = NINT(nwidth*dx)
        write(vsdbline(lvsdb0+1:160),80) kmwidth,vacc,                        &
 &           int(pthresh(ithresh)),pthresh(ithresh)-int(pthresh(ithresh)),    &
 &           N, FBS, SUMf, SUMo 
 80     format(i3.3,' APCP/',i2.2,'>', i3.3,f0.1, ' SFC =', i7, x, 3(1x,e12.5))
        lvsdb = LEN_TRIM(vsdbline)
        write(fmt,85) lvsdb
 85     format('(a',i3.3,')')
        write(51,fmt) vsdbline(1:lvsdb)
 90   CONTINUE  ! loop for each box width
100 CONTINUE ! loop for each threshold
    GOTO 999 

998 STOP 'Mask read error, stop'

999 CONTINUE

    STOP
    END PROGRAM Fractional_Skill_Scores

