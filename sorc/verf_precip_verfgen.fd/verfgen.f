      program verfgen
!
! 2003/9/11: changed 'string' length from 80 to 120 to accommodate 
!   the lengthy model names used in WRF retro runs.
! 2003/9/26: modified code to handle new sub-region masks
!
! 2007/9/11: Replaced the old 'WS8/CN8/EA8' with the new hi-res window masks
!   'WST/EST'. 
! 2010/01/11: Increased number of thresholds from 9 to 10:
!               added 4"/day for daily verif; 0.75"/3hr for 3-hourly verif
!            Added an additional special region (in additional to WST/EST):
!               No. 43 (HDN) for Howard A. Henson run.  As of 2010/12/20, HDN
!               is not in use and this slot is kept as a place-holder.
! 2010/12/20: Added SL1L2 calculation for G212 verification.
! 2011/05/17: Added 3 OCONUS regions (PUR, HWI, ASK)
! 2012/07/23  Y. Lin:  Convert to ifort for Zeus/WCOSS
! 2016/10/28 Y. Lin: added a 6th significant digit to FHO.
! 
! I/O units
!   Input:
!     fort.11: model file
!     fort.12: analysis file
!     fort.13: grid mask   
!   Output:
!     fort.51: VSDB file
!
! Parameters:
!   imax     : Maximum dimension of precip arrays.  Currently the 
!              max is for Grid 218 (614x428=262792).
!   numthr   : Number of precipitation amount thresholds in verification
!   mxnumreg : Maximum number of subregions used in verification.  The
!              sub-regions and their corresponding mask values are:
!                09 NW! Northern West Coast
!                10 SWC Southern West Coast
!                11 NMT Northern Mountain
!                12 GRB Great Basin
!                13 SMT Southern Mountain
!                14 SWD Southwest Desert
!                15 NPL Northern Plains
!                16 SPL Southern Plains
!                17 MDW Midwest
!                18 LMV Lower Mississippi Valley
!                19 APL Appalachians
!                20 NEC Northern East Coast
!                21 SEC Southern East Coast
!                30 GMC Gulf of Mexico Coast
!                41 WST Western HiRes Window
!                42 EST Eastern HiRes Window
!                43 HDN Domain for the Howard A. Henson run (HDN)
!                44 PUR Domain for the Puerto Rico nest
!                45 HWI Domain for the Hawaii nest
!                46 ASK Domain for the Alaska nest
!                99 RFC ConUS (=09+10+...+20+21+30)
!  01-08, 22-29 are used in surface and upperair verification but not
!  in precipitation verification (they are outside of ConUS).  
!  31-40 are not used.
!
      parameter(imax=10000000,numthr=10,mxnumreg=99)
      dimension pmod(imax), panl(imax), mask(imax), thresh(numthr)
      logical*1 mbit(imax), abit(imax)
      character string*120, thr24(numthr)*3,thr3(numthr)*3,                   &
         fmask(mxnumreg)*3, vsdb0*80, vsdbline*160, fmt*6
!
      integer mpds(200),mgds(200),apds(200),agds(200),                        &
        jpds(200),jgds(200), listreg(mxnumreg),                               &
        vacc ! length of verification hour (=24,3, etc.)                   
      data thr24 /'.01','.10','.25','.50','.75','1.0','1.5','2.0','3.0','4.0'/
      data thr3  /'.01','.02','.05','.10','.15','.25','.35','.50','.75','1.0'/
!
! There are now 33 regions defined, though only 17 of them are in use
! (mask values 0, 9-22, 30, 31,32.  The last two are for the hi-res windows
! (east and west)
! 
!
      data fmask                                          &                    
       / 'ATC','WCA','ECA','NAK','SAK','HWI','NPO','SPO'  & ! 01-08: not used  
       , 'NWC','SWC','NMT','GRB','SMT','SWD','NPL','SPL'  & ! 09-16           
       , 'MDW','LMV','APL','NEC','SEC'                    & ! 17-21            
       , 'NAO','SAO','PRI','MEX','GLF','CAR','CAM','NSA'  & ! 22-29: not used  
       , 'GMC'                                            & ! 30               
       , '   ','   ','   ','   ','   ','   ','   ','   '  & ! 31-38: vacant    
       , '   ','   '                                      & ! 39-40: vacant    
       , 'WST','EST','HDN','PUR','HWI','ASK'              & ! 41-46: Hires Win 
       , 52*'   ','RFC' /                                   ! 47-98, vacant; 99
!
      integer f,h,o,t
      integer fg(imax),hg(imax),og(imax),tg(imax)
!
      jpds = -1
!
! Read in model name: 
      call getenv("MODNAM",string)
      lmodnam=len_trim(string)
!
! 'V01 ETA '
!  ^^^^^^^^
      vsdb0='V01 ' // string(1:lmodnam)
      lvsdb0=len_trim(vsdb0) + 1  ! length includes one trailing blank
!
! Read in forecast hour:
      call getenv("fhour",string)
      lfhour=len_trim(string)
! 'V01 ETA 36 '
!          ^^
      vsdb0=vsdb0(1:lvsdb0)//string(1:lfhour)
      lvsdb0=len_trim(vsdb0) + 1  ! length includes one trailing blank
      
! Read in verification time length (24h, 3h etc.)
      call getenv("vacc",string)
      read(string(1:2),'(i2)') vacc
!
! Read in verification time: 
      call getenv("vdate",string)
! 'V01 ETA 36 2002070812'
!             ^^^^^^^^^^
      vsdb0(lvsdb0+1:lvsdb0+10) = string(1:10)
      lvsdb0=len_trim(vsdb0)
!
!
! Read in verifying analysis type (CPCANL, STAGE2, or STAGE4)
      call getenv("VERFANL",string)
      lverfanl=len_trim(string)
      vsdb0 = vsdb0(1:lvsdb0)//' '//string(1:lverfanl)//' G'
! 'V01 NAM 36 2008062112 CPCANL G'
!                       ^^^^^^^^^
      lvsdb0=len_trim(vsdb0)
!
! Read in model precip file:
      call baopenr(11,'fort.11',ibret)
      call getgb(11,0,imax,0,jpds,jgds,km,k,mpds,mgds,mbit,pmod,imret)
      write(6,*) 'Openning ',string(1:len),', ibret=', ibret,                 &
                 ' imret=', imret
!
! Read in analysis precip file:
      call baopenr(12,'fort.12',ibret)
      call getgb(12,0,imax,0,jpds,jgds,ka,k,apds,agds,abit,panl,iaret)
      write(6,*) 'Openning ',string(1:len),', ibret=', ibret,                 &
                 ' iaret=', iaret
!
      if (imret.ne.0 .or. iaret.ne.0) then
        write(6,*) 'File read error, STOP. imret, ioret=',imret,ioret
        stop
      endif
!
! Make sure that the model precip file has the same grid number and
! date stamp as the analysis precip file:
!
      if (mpds(3).ne.apds(3)) then
        write(6,*) 'STOP: model and obs precip grids are different, ',        &
                   ' mpds(3)/apds(3)=',mpds(3), apds(3)
        stop
      endif
!
      if (km.ne.ka) then
        write(6,*) 'STOP: model and obs precip grid dimensions are ',         &
                   ' different, km/ka=', km, ka
        stop
      endif
!
      write(6,10) (mpds(21)*100+mpds(8))/100-1, mod(mpds(8),100),             &
                  mpds(9), mpds(10), mpds(11), mpds(14), mpds(15)
 10   format('Mod pcp: ', 5i2.2, ' cycle, ', i2.2,'-',i2.2,'h fcst')
!
      write(6,20) (apds(21)*100+apds(8))/100-1, mod(apds(8),100),             &
                  apds(9), apds(10), apds(11), apds(14), apds(15)
 20   format('Anl pcp: ', 5i2.2, ' cycle, ', i2.2,'-',i2.2,'h accu')
!
! 'V01 ETA 36 2002070812 CPCANL G212/
!                                ^^^^
! All the verification grid from now on should be 3 digits (yl: 2002/7/10).
! Still, just in case - 
      write(vsdb0(lvsdb0+1:lvsdb0+4),"(i3.3,'/')") mpds(3)
      lvsdb0=lvsdb0+4
!
! Determine which region(s) we will be verifying:
!
! Keep all the regions we'll be verifying in 'listreg'.  The number of 
! regions will be in 'numreg'.  The follow are examples of what 'listreg' 
! and 'numreg' should look like for various verification opations
! (valid values for regions are ********
!  1. On grid 211/212/218, no nests. 14 sub-regions, plus ConUS (listreg=99):
!       numreg  = 15
!       listreg =  9, 10, 11, 12, ...., 20, 21, 30, 99, -1, -1, -1 ...
!  
!  2. For HiRes Windows, either 'east' or 'west'
!       numreg  =  1
!       listreg = 41 (or 42), -1, -1, -1, ...
!
! Read in the mask:
      mask=-1
      listreg = -1
!
      read(13) (mask(i),i=1,km)
! Is this going to be verification for an Eta nest?  (if so, do not
!   verify on the entire CONUS [i.e. the 'RFC' region)
!   if maxmask > 40, then we are verifying for a 'nest' region:
!
      maxmask = maxval(mask)
      if (maxmask .le. 40) then
! No nest:
        numreg = 15
        listreg(1) = 0
        do k = 1, 13
          listreg(k) = k + 8
        enddo
        listreg(14)= 30
        listreg(15)= 99
      else
! Nest:
        listreg(1) = maxmask
        numreg = 1
      endif  ! Nest?
!
! Read in verification threshold values (in inches), convert to mm:
!
      do 30 k = 1, numthr
        if (vacc .eq. 24) then
           read(thr24(k),*) thresh(k)
        else
           read( thr3(k),*) thresh(k)
        endif
 30   continue
!
! Now verify:
      do 80 k = 1, numthr
! For each threshold, go through the entire grid: at each grid point,
! find out whether the model and analysis precip values exceed the
! threshold value:
        tg=0
        og=0
        fg=0
        hg=0
!
        threshmm = thresh(k)*25.4
!
        do 40 i = 1, km
! if model and analysis both have valid precipitation values (zero 
! or non-zero)at this point ('mbit' is false if this verification
! point is outside of the model domain; 'abit' is false if this point
! have no valid precipitation analysis):
          if (mbit(i) .and. abit(i)) then
            tg(i) = 1
            if (panl(i).gt.threshmm) og(i) = 1
            if (pmod(i).gt.threshmm) fg(i) = 1
            if (panl(i).gt.threshmm .and. pmod(i).gt.threshmm)                &
               hg(i) = 1
          endif
 40     continue
!
! Now calculate scores for each regions we will be verifying:
!
! (Conus values are a sum of all sub-regions)
        t_rfc=0
        o_rfc=0
        f_rfc=0
        h_rfc=0

        do 70 j=1, numreg
          t=0
          o=0
          f=0
          h=0
!
! If this is a sub-region, go through each grid point to see if it belongs 
! to the region/subregion we are verifiying.  For ConUS ('rfc', listreg(j)=99),
! sum up T/F/H/O for all ConUS subregions.
!
          if (listreg(j).lt.99) then
            do 50 i = 1, km
              if (mask(i).eq.listreg(j)) then
                t=t+tg(i)
                o=o+og(i)
                f=f+fg(i)
                h=h+hg(i)
              endif
 50         continue 
            t_rfc=t_rfc+t
            o_rfc=o_rfc+o
            f_rfc=f_rfc+f
            h_rfc=h_rfc+h
          else
            t=t_rfc
            o=o_rfc
            f=f_rfc
            h=h_rfc
          endif
!
          if (t.gt.0) then
            fot=float(f)/float(t)
            hot=float(h)/float(t)
            oot=float(o)/float(t)
! 'V01 ETA 36 2002070812 MC_PCP G212/NEC FHO>
!                                    ^^^^^^^^
            vsdbline=vsdb0(1:lvsdb0)//fmask(listreg(j))//' FHO>'
            lvsdb=len_trim(vsdbline)
! 
! 'V01 ETA 36 2002070812 MC_PCP G212/NEC FHO>1.5
!                                            ^^^
            if (thresh(k).lt.1.0) then
              write(vsdbline(lvsdb+1:lvsdb+3),'(f3.2)') thresh(k)
            else
              write(vsdbline(lvsdb+1:lvsdb+3),'(f3.1)') thresh(k)
            endif
            lvsdb = lvsdb + 3
!
! 'V01 ETA 36 2002070812 MC_PCP G212/NEC FHO>1.5 APCP/
!                                               ^^^^^^
            vsdbline=vsdbline(1:lvsdb)//' APCP/'
            lvsdb=len_trim(vsdbline)
! 'V01 ETA 36 2002070812 MC_PCP G212/NEC FHO>1.5 APCP/24
!                                                     ^^
!
            write(vsdbline(lvsdb+1:lvsdb+2),'(i2.2)') vacc
            lvsdb = lvsdb + 2
!
! 'V01 ETA 36 2002070812 MC_PCP G212/NEC FHO>1.5 APCP/24 SFC = '
            vsdbline=vsdbline(1:lvsdb)//' SFC ='
! FVS requires a blank space before and after '='.  Include a trailing blank:
            lvsdb=len_trim(vsdbline) + 1 
!
! 'V01 ETA .... FHO>1.5 APCP/24 SFC =   3232  .00031  .00000  .00217
!                                     ----:----|----:----|----:----|
! 2016/10/28 change the above to (e.g. add the 6th significant digit to FHO):
! 'V01 NAM .... FHO>1.5 APCP/24 SFC =   3232  .00031x  .00000x  .00217x
!                                     ----:----|----:----|----:----|---
! 
            write(vsdbline(lvsdb+1:lvsdb+33),60) t, fot, hot, oot
 60         format(i6,3f9.6)
            lvsdb=len_trim(vsdbline)
!
! A VSDB line is now complete.  Write it out:
            write(fmt,62) lvsdb
 62         format('(a',i3.3,')')
            write(51,fmt) vsdbline(1:lvsdb)
          endif  ! if t > 0, for a given region
 70     continue ! Loop through verification regions
 80   continue   ! Loop through precip thresholds
!
!  For grid 212 and 218, compute domain/subdomain-averaged precip amounts for 
!  Forecast and Observation (amount averaged over grid points that have 
!  valid values in both F & O).  Also do this for oconus grids: 194, 196, 198.
!  Just skip it for g211 verif.  
!      if (mpds(3).ne.212 .and. mpds(3).ne.218) go to 200
      if (mpds(3).eq.211) go to 200
!
!  Format of the VSDB:
!  24h verif:
!  V01 NAM 36 2006042712 CPCANL G218/NWC SL1L2 APCP/24 SFC = 84 F O F*O F*F O*O
!  3h verif:
!  V01 NAM 33 2006042703 STAGE2 G218/NWC SL1L2 APCP/03 SFC = 84 F O F*O F*F O*O
!
!  Make template for vsdb line.  There is some duplication between this 
!  and the FHO calculation.  Consolidate this during the next code overhaul.
!
! Read in model name: 
      call getenv("MODNAM",string)
      lmodnam=len_trim(string)
!
! 'V01 ETA '
!  ^^^^^^^^
      vsdb0='V01 ' // string(1:lmodnam)
      lvsdb0=len_trim(vsdb0) + 1  ! length includes one trailing blank
!
! Read in forecast hour:
      call getenv("fhour",string)
      lfhour=len_trim(string)
! 'V01 ETA 36 '
!          ^^
      vsdb0=vsdb0(1:lvsdb0)//string(1:lfhour)
      lvsdb0=len_trim(vsdb0) + 1  ! length includes one trailing blank
      
! Read in verification time length (24h, 3h etc.)
      call getenv("vacc",string)
      read(string(1:2),'(i2)') vacc
!
! Read in verification time: 
      call getenv("vdate",string)
! 'V01 ETA 36 2002070812'
!             ^^^^^^^^^^
      vsdb0(lvsdb0+1:lvsdb0+10) = string(1:10)
      lvsdb0=len_trim(vsdb0)
! 'V01 ETA 36 2002070812 CPCANL G'
!                       ^^^^^^^^^
! Read in verifying analysis type (CPCANL, STAGE2, or STAGE4)
      call getenv("VERFANL",string)
      lverfanl=len_trim(string)
      vsdb0 = vsdb0(1:lvsdb0)//' '//string(1:lverfanl)//' G'
!
      lvsdb0=len_trim(vsdb0)
! 'V01 ETA 36 2002070812 CPCANL G218
!                                ^^^
      write(vsdb0(lvsdb0+1:lvsdb0+4),"(i3.3,'/')") mpds(3)
      lvsdb0=lvsdb0+4
!
      do 170 j = 1, numreg
        avgf=0.   
        avgo=0.   
        fo=0.
        ff=0.
        oo=0.
        npts=0    ! number of points with valid F & O data
!
        do 150 i = 1, km
          if (mbit(i) .and. abit(i)) then
            if (listreg(j).lt.99 .and. mask(i).eq.listreg(j)                  &
               .or. listreg(j).eq.99 .and.                                    &
               (mask(i).ge.9.and.mask(i).le.21 .or. mask(i).eq.30)) then
              npts=npts+1
              avgf=avgf+pmod(i)
              avgo=avgo+panl(i)
              fo=fo+pmod(i)*panl(i)
              ff=ff+pmod(i)*pmod(i)
              oo=oo+panl(i)*panl(i)
            endif
          endif
 150    continue
!
        if (npts .gt. 0) then
          avgf=avgf/float(npts)
          avgo=avgo/float(npts)
          fo=fo/float(npts)
          ff=ff/float(npts)
          oo=oo/float(npts)
! 'V01 NAM 36 2002070812 AVGPCP G218/NWC SL1L2 APCP/'
          vsdbline=vsdb0(1:lvsdb0)//fmask(listreg(j))//' SL1L2 APCP/'
          lvsdb=len_trim(vsdbline)
! 'V01 NAM 36 2002070812 AVGPCP G218/NWC SL1L2 APCP/24 SFC= '
          write(vsdbline(lvsdb+1:lvsdb+7),"(i2.2,' SFC=')") vacc
          lvsdb=len_trim(vsdbline)
          write(vsdbline(lvsdb+1:160),'(i8,5e11.4)')                          &
     &            npts, avgf, avgo, fo, ff, oo
          lvsdb=len_trim(vsdbline)
          write(fmt,62) lvsdb   ! '62' is defined earlier in the FHO section.
!
! A VSDB line is now complete.  Write it out:
          write(51,fmt) vsdbline(1:lvsdb)
        endif
 170  continue ! go to next subregion number
!
 200  continue ! skip the AVG_PCP computation if not grid 212/218
! 
      stop
      end
 

