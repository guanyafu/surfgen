! load coordinate sets

SUBROUTINE readCoordSets()
  use hddata,  only:ncoord,order,getFLUnit
  use progdata,only:nrij,nout,printlvl,natoms,atomCount,atomList,&
       nCoordSets,CoordSet,coordmap,nCoordCond,CoordCond,condRHS
  implicit none
  character(72)            :: comment
  character(4)             :: str
  integer                  :: ios,i,j,k,l,m,n,&
                              CSETFL,       &  !Unit ID for coordinate definition file
                              nAddCond         !number of additional conditions
! temporary variables used to generate definitions
  integer                  :: tmpCoord(natoms**4,4),& ! temporary coordinate definition holder
                              rawCoord(4),ordOOP(4),& ! atoms referenced, before and after ordering
                              prty                    ! parity of OOP angle, just a dummy variable
  integer,dimension(:),allocatable   ::  lhs          ! Left hand side of coordinate order restrictions
  CSETFL=getFLUnit()
! total coordinates count
  ncoord=0
! total coordinate condition count
  nCoordCond=0

! Load coordinate definition file
  if(printlvl>0)print *,"   Reading coordinate set definitions."
  open(unit=CSETFL,file='coord.in',access='sequential',form='formatted',&
    STATUS='OLD',ACTION='READ',POSITION='REWIND',IOSTAT=ios)
  read(CSETFL,1000,IOSTAT=ios) comment
! Get number of coordinate sets and additional conditions
  read(CSETFL,*,IOSTAT=ios) nCoordSets,nAddCond
  if(ios/=0.or.nCoordSets<1)stop"Error reading coord set definitions."

  if(allocated(CoordSet))deallocate(CoordSet)
  allocate(CoordSet(nCoordSets))

  if(printlvl>0)Print *,"      generating",nCoordSets," sets"  
  allocate(lhs(nCoordSets))

  do i=1,nCoordSets
! read in definition for one set of coordinates
    read(CSETFL,1000,IOSTAT=ios) comment
    read(CSETFL,'(3I4)',IOSTAT=ios)CoordSet(i)%Type,CoordSet(i)%Scaling,CoordSet(i)%Order
    read(CSETFL,'(4I4)',IOSTAT=ios)CoordSet(i)%AtomGrp
    if(ios/=0)stop "Error reading coord set definitions."
! check order settings
    if(CoordSet(i)%Order<0)stop "Error:  Wrong maximum order value"
    if(CoordSet(i)%Order==0.or.CoordSet(i)%Order>=order)then
       CoordSet(i)%Order=order
    else
       nCoordCond=nCoordCond+1
    end if!(CoordSet(i)%Order==0.or.CoordSet(i)%Order>order)
    if(printlvl>0)Print '("     set ",I4," type=",I4 ," scaling=",I4," max order=",I4)',&
                                i,CoordSet(i)%Type,CoordSet(i)%Scaling,CoordSet(i)%Order

    select case(CoordSet(i)%Type)

!----Plain or Scaled Internuclear distance coordinate

      case(0)  !rij or scaled rij.   %atomGrp = A1 , A2 ,  X , X

! field 1 and 2 of atomGrp record the atom group the end point atoms belong to
! field 3 and 4 are not used
          if(CoordSet(i)%atomGrp(1).eq.CoordSet(i)%atomGrp(2))theN
! bond between same type of atoms
! determine number of coordinates contained in the set
            CoordSet(i)%ncoord  =  atomCount(CoordSet(i)%atomGrp(1))  *     &
                        (atomCount(CoordSet(i)%atomGrp(1))-1)/2
! allocate memory for field Coord, definition of all the coordinates in the set
            if(allocated(CoordSet(i)%coord))deallocate(CoordSet(i)%coord)
            allocate(CoordSet(i)%coord(CoordSet(i)%ncoord,2))
! make coord list
            l = 1
            do j=1,atomCount(CoordSet(i)%atomGrp(1))
              do k=j+1,atomCount(CoordSet(i)%atomGrp(1))
                CoordSet(i)%coord(l,1) = atomList(CoordSet(i)%atomGrp(1),j)
                CoordSet(i)%coord(l,2) = atomList(CoordSet(i)%atomGrp(1),k)
                l=l+1
              end do !k
            end do !j
          else   !(CoordSet(i)%atomGrp(1).eq.CoordSet(i)%atomGrp(2))
! bond between different types of atoms
            CoordSet(i)%ncoord  =  atomCount(CoordSet(i)%atomGrp(1))  *     &
                                        atomCount(CoordSet(i)%atomGrp(2))
            allocate(CoordSet(i)%coord(CoordSet(i)%ncoord,2))
! make coord list
            l = 1
            do j=1,atomCount(CoordSet(i)%atomGrp(1))
              do k=1,atomCount(CoordSet(i)%atomGrp(2))
                CoordSet(i)%coord(l,1) = atomList(CoordSet(i)%atomGrp(1),j)
                CoordSet(i)%coord(l,2) = atomList(CoordSet(i)%atomGrp(2),k)
                l=l+1
              end do !k
            end do !j
          end if !(CoordSet(i)%atomGrp(1).eq.CoordSet(i)%atomGrp(2))
! Read in scaling parameters if is scaled Rij
        allocate(CoordSet(i)%Coef(2))
        if(CoordSet(i)%Scaling.ne.0)then
          read(CSETFL,'(2F10.6)',IOSTAT=ios) CoordSet(i)%Coef(:)
          if(ios/=0)stop "Error reading coord set definitions."
        end if !(CoordSet(i)%Scaling.ne.0)


!-- Out of plane angle coordinate


      case(-1) ! OOP.   %atomGrp = A1, A2, A3, A4

        CoordSet(i)%ncoord=0
! Generate all possible 4 combinations.  Only the ones that are cannonically
! ordered will be inserted into the list.
        do j=1,atomCount(CoordSet(i)%atomGrp(1))
          rawCoord(1) =  atomList(CoordSet(i)%atomGrp(1),j) 
          do k=1,atomCount(CoordSet(i)%atomGrp(2))
            rawCoord(2) =  atomList(CoordSet(i)%atomGrp(2),k) 
            if(rawCoord(2)==rawCoord(1))cycle
            do m=1,atomCount(CoordSet(i)%atomGrp(3))
              rawCoord(3) =  atomList(CoordSet(i)%atomGrp(3),m) 
              if(count(rawCoord(3)==rawCoord(1:2))>0)cycle
              do n=1,atomCount(CoordSet(i)%atomGrp(4))
                rawCoord(4) =  atomList(CoordSet(i)%atomGrp(4),n) 
                if(count(rawCoord(4).eq.rawCoord(1:3))>0)cycle  !all indices have to be different
                call reorderOOP(rawCoord,ordOOP,prty)
                if(count(rawCoord.eq.ordOOP).eq.4)then ! the atoms are cannonically ordered
                  CoordSet(i)%ncoord = CoordSet(i)%ncoord+1
                  tmpCoord( CoordSet(i)%ncoord , : ) = rawCoord
                end if ! count(...).eq.4
              end do !n
            end do !m
          end do !k
        end do ! j
! allocate field %coord and transfer definition from temporary array to global structure
        if(allocated(CoordSet(i)%coord))deallocate(CoordSet(i)%coord)
        allocate(CoordSet(i)%coord(CoordSet(i)%ncoord,4))
        CoordSet(i)%coord = tmpCoord(:CoordSet(i)%ncoord,:)

! load scaling factor
        allocate(CoordSet(i)%Coef(2))
        read(CSETFL,'(2F10.6)',IOSTAT=ios) CoordSet(i)%Coef
        if(ios/=0)stop "Error reading coord set definitions."

      case(-2) ! OOP.   %atomGrp = A1, A2, A3, A4

        CoordSet(i)%ncoord=0
! Generate all possible 4 combinations.  Only the ones that are cannonically
! ordered will be inserted into the list.
        do j=1,atomCount(CoordSet(i)%atomGrp(1))
          rawCoord(1) =  atomList(CoordSet(i)%atomGrp(1),j) 
          do k=1,atomCount(CoordSet(i)%atomGrp(2))
            rawCoord(2) =  atomList(CoordSet(i)%atomGrp(2),k) 
            if(rawCoord(2)==rawCoord(1))cycle
            do m=1,atomCount(CoordSet(i)%atomGrp(3))
              rawCoord(3) =  atomList(CoordSet(i)%atomGrp(3),m) 
              if(count(rawCoord(3)==rawCoord(1:2))>0)cycle
              do n=1,atomCount(CoordSet(i)%atomGrp(4))
                rawCoord(4) =  atomList(CoordSet(i)%atomGrp(4),n) 
                if(count(rawCoord(4).eq.rawCoord(1:3))>0)cycle  !all indices have to be different
                call reorderOOP(rawCoord,ordOOP,prty)
                if(count(rawCoord.eq.ordOOP).eq.4)then ! the atoms are cannonically ordered
                  CoordSet(i)%ncoord = CoordSet(i)%ncoord+1
                  tmpCoord( CoordSet(i)%ncoord , : ) = rawCoord
                end if ! count(...).eq.4
              end do !n
            end do !m
          end do !k
        end do ! j
! allocate field %coord and transfer definition from temporary array to global structure
        if(allocated(CoordSet(i)%coord))deallocate(CoordSet(i)%coord)
        allocate(CoordSet(i)%coord(CoordSet(i)%ncoord,4))
        CoordSet(i)%coord = tmpCoord(:CoordSet(i)%ncoord,:)

! load scaling factor
        allocate(CoordSet(i)%Coef(2))
        read(CSETFL,'(2F10.6)',IOSTAT=ios) CoordSet(i)%Coef
        if(ios/=0)stop "Error reading coord set definitions."


! no coefficient to read for OOP

!---Bond angle coordinates and their periodic scalings

      case(1)  ! angle A1-A2-A3.   %atomGrp = A1, A2, A3, X. 

        CoordSet(i)%ncoord=0
! Generate all possible 4 combinations.  Only the ones that are cannonically
! ordered will be inserted into the list. (ie, A3>A1 when same type, and that
! A1,A2,A3 are all different )
        do j=1,atomCount(CoordSet(i)%atomGrp(1))
          rawCoord(1) =  atomList(CoordSet(i)%atomGrp(1),j)
          do k=1,atomCount(CoordSet(i)%atomGrp(2))
            rawCoord(2) =  atomList(CoordSet(i)%atomGrp(2),k)
            if(rawCoord(2).eq.rawCoord(1))cycle
            do l=1,atomCount(CoordSet(i)%atomGrp(3))
              rawCoord(3) =  atomList(CoordSet(i)%atomGrp(3),l)
              if(CoordSet(i)%atomGrp(1).eq.CoordSet(i)%atomGrp(3)  .and. &
                          rawCoord(3)<=rawCoord(1) .or. rawCoord(3).eq.rawCoord(2))  cycle
              CoordSet(i)%ncoord = CoordSet(i)%ncoord+1
              tmpCoord( CoordSet(i)%ncoord , 1:3 ) = rawCoord(1:3)
            end do !l
          end do !k
        end do ! j

! allocate field %coord and transfer definition from temporary array to global structure
        if(allocated(CoordSet(i)%coord))deallocate(CoordSet(i)%coord)
        allocate(CoordSet(i)%coord(CoordSet(i)%ncoord,3))
        CoordSet(i)%coord = tmpCoord(:CoordSet(i)%ncoord,1:3)

! no scaling parameters for bond angles

!---Torsion angle coordinates and their periodic scalings

      case (2) ! torsion A1-A2-A3-A4.   %atomGrp = A1, A2, A3, A4

        CoordSet(i)%ncoord=0
! cannonical order = A3>A2 and all atom indices are different
        do j=1,atomCount(CoordSet(i)%atomGrp(1))
          rawCoord(1) =  atomList(CoordSet(i)%atomGrp(1),j)
          do k=1,atomCount(CoordSet(i)%atomGrp(2))
            rawCoord(2) =  atomList(CoordSet(i)%atomGrp(2),k)
            if(rawCoord(2).eq.rawCoord(1))cycle
            do m=1,atomCount(CoordSet(i)%atomGrp(3))
              rawCoord(3) =  atomList(CoordSet(i)%atomGrp(3),m)
              if(rawCoord(3).eq.rawCoord(1) .or. rawCoord(3)<=rawCoord(2))cycle
              do n=1,atomCount(CoordSet(i)%atomGrp(4))
                rawCoord(4) =  atomList(CoordSet(i)%atomGrp(4),n)
                if(count(rawCoord(4).eq.rawCoord(1:3))>0)cycle  !all indices have to be different
                CoordSet(i)%ncoord = CoordSet(i)%ncoord+1
                tmpCoord( CoordSet(i)%ncoord , : ) = rawCoord
              end do !n
            end do !m
          end do !k
        end do ! j

! allocate field %coord and transfer definition from temporary array to global structure
        if(allocated(CoordSet(i)%coord))deallocate(CoordSet(i)%coord)
        allocate(CoordSet(i)%coord(CoordSet(i)%ncoord,4))
        CoordSet(i)%coord = tmpCoord(:CoordSet(i)%ncoord,:)

! no coefficient to read for torsion

!-- Other types

      case default
        print *,"TYPE=",CoordSet(i)%Type
        stop "Error : COORDINATE TYPE NOT SUPPORTED. "
    end select!case(CoordSet(i)%Type)

! %icoord  maps coordinate index inside set to full coordinate list index

    allocate(CoordSet(i)%icoord(CoordSet(i)%ncoord))
    do j=1,CoordSet(i)%ncoord
      CoordSet(i)%icoord(j)=j+ncoord
    end do!j=1,CoordSet(i)%ncoord
    ncoord=ncoord+CoordSet(i)%ncoord

  end do!i=1,nCoordSets

! generate coordinate map from full coordinate list to coordinate set list
  if(allocated(coordmap))deallocate(coordmap)
  allocate(coordmap(ncoord,2))
  k=0
  do i=1,nCoordSets
    do j=1,CoordSet(i)%ncoord
      k=k+1
      coordmap(k,1)=i   !(:,1) = index of set
      coordmap(k,2)=j   !(:,2) = index within a set
    end do!j=1,CoordSet(i)%ncoord
  end do!i=1,nCoordSets

!Generate coordinate inequality conditions for hddata
  allocate(CoordCond(nCoordCond+nAddCond,ncoord))
  allocate(condRHS(nCoordCond+nAddCond))
  nCoordCond=0
  CoordCond=0

! Generate individual set order limits
  do i=1,nCoordSets
    if(CoordSet(i)%Order>=order)cycle
    nCoordCond=nCoordCond+1
    CoordCond(nCoordCond,CoordSet(i)%icoord)=1
    condRHS(nCoordCond)=CoordSet(i)%Order
  end do!i=1,nCoordSets

! Additional set order restrictions
  write(str,'(I4)') nCoordSets+1
  if(printlvl>0)print *,"      Reading ",naddcond," additional order restrictions."
  do i=1,nAddCond
    nCoordCond=nCoordCond+1
    read(CSETFL,"("//trim(str)//"I4)",IOSTAT=ios) lhs,condRHS(nCoordCond)
    if(ios/=0)stop "Error reading addintional coordinate order restrictions."
    if(printlvl>1)print *,"      lhs: ",lhs," rhs:",condRHS(nCoordCond)
    do j=1,nCoordSets
      CoordCond(nCoordCond,CoordSet(j)%icoord)=lhs(j)
    end do
  end do
  close(unit=CSETFL)
  deallocate(lhs)
1000 format(72a)
END SUBROUTINE

! load irrep matrices from irrep.in
SUBROUTINE readIrreps()
  use progdata, only:IRREPFL,printlvl
  use CNPI, only:  nirrep, irrep, deallocIrreps
  IMPLICIT NONE
  character(72)            ::  comment
  character(3)             ::  tpStr
  integer                  ::  i,j,k,d,ordr,ios

  call deallocIrreps()
  open(unit=IRREPFL,file='irrep.in',access='sequential',form='formatted',&
      STATUS='OLD',ACTION='READ',POSITION='REWIND',IOSTAT=ios)
  if(ios/=0)stop "readIrreps:  cannot open file irrep.in"
  read(IRREPFL,1000) comment
  read(IRREPFL,1001) nirrep
  if(printlvl>0)print *,"    Loading irreducible representations...."
  if(printlvl>1)print *,"    ",trim(comment)
  if(printlvl>1)print *,"      Number of irreps: ",nirrep
  allocate(irrep(nirrep))
  do i=1,nirrep
    read(IRREPFL,1000) comment
    if(printlvl>2)print '(7x,"Irrep #",I2," : ",a)',i,trim(adjustl(comment))
    read(IRREPFL,1002)  d,ordr
    irrep(i)%Dim   = d
    irrep(i)%Order = ordr
    write(tpStr,'(I3)') d
    allocate(irrep(i)%RepMat(ordr,d,d))
    do j=1,ordr
      do k=1,d
        read(IRREPFL,'('//trim(tpStr)//'F14.10)') irrep(i)%repmat(j,k,1:d)
        if(printlvl>2)print '(11X,'//trim(tpStr)//'F14.10)',irrep(i)%repmat(j,k,1:d)
      end do!k=1,d
      if(printlvl>2)print *,''
    end do!j=1,ordr
  end do!i=1,nirrep
  close(unit=IRREPFL)
1000 format(72a)
1001 format(7x,I6)
1002 format(3X,I6,5X,I6)
END SUBROUTINE

! read reference geometry/energy/internal coordiante/gradients from input file
! also generates global coordiantes and symmetrized polynomial basis
! b matrices are calcualted and reference geometry is symmetrized
SUBROUTINE initialize(jobtype)
  use hddata
  use progdata
  use CNPI
  IMPLICIT NONE
  INTEGER,INTENT(IN)                          :: jobtype
  
  if(printlvl>0)print *,"Entering Initialize()"
  if(printlvl>0)print *,"    generating atom permutation"
  Call genAtomPerm()
  if(printlvl>0)print *,"    generating Rij permutations"
  call readCoordSets()
  if(printlvl>0)print *,"    generating permutations for scaled coordinates"
  call genCoordPerm()
  CALL initHd()
  if(printlvl>0)print *,"    generating term list"
  Call genTermList(nCoordCond,CoordCond,condRHS)
  if(printlvl>0)print *,"    partitioning term list"
  Call PartitionTerms()

  if(printlvl>0)print *,"    generating Maptab"
  call genMaptab()

  !allocate space for Hd  
  call allocateHd(eguess)
  if(inputfl/='')then 
    if(printlvl>0)print *,"  Reading Hd Coefficients from ",trim(inputfl)
    call readHd(inputfl)
  end if!(inputfl/='')
  call printTitle(jobtype)
  
  if(printlvl>0)print *,"Exiting Initialize()"
end SUBROUTINE initialize

!-------------------------------------------------------------------
!load COLUMBUS geometries on disk and output energies, gradients
!and derivative couplings predicted by Hd, also in COLUMBUS format
!
SUBROUTINE loadgeom()
  use hddata, only: nstates, ncoord, makehmat, getFLUnit, makedhmat
  use progdata, only: natoms,loopst,ngeoms,isloop,geomfl, outputdiab,&
                      AU2CM1,eshift,calchess,abpoint,outputdir,eshift
  IMPLICIT NONE
  TYPE(abpoint)                                   :: loadgeoms
  INTEGER                                         :: i,j,k
  CHARACTER(4)                                    :: ind,jnd
  CHARACTER(72)                                   :: fname,enerfl
  CHARACTER(72),dimension(nstates)                :: gradfl
  CHARACTER(72),dimension(nstates*(nstates-1)/2)  :: cpfl
  CHARACTER(3),dimension(natoms)                  :: atoms
  DOUBLE PRECISION,dimension(natoms)              :: anums,masses
  double precision,dimension(nstates,nstates)        :: hmat,evec 
  double precision,dimension(ncoord,nstates,nstates) :: dhmat
  integer                                         :: m,LWORK,LIWORK,INFO,GUNIT,ios
  integer,dimension(nstates*2)                    :: ISUPPZ
  double precision,dimension(nstates*(nstates+26)):: WORK
  integer,dimension(nstates*10)                   :: IWORK
  double precision,dimension(ncoord,nstates,nstates)    :: igrads
  double precision,dimension(3*natoms,nstates,nstates)  :: cgrads,dcgrads
  character(30)  :: fmtstr,fmtstr2

  LWORK  = nstates*(nstates+26)
  LIWORK = nstates*10
  write(fmtstr,'(I3)')nstates
  write(fmtstr2,'(I3)')nstates*nstates
  fmtstr='('//trim(adjustl(fmtstr))//'(F16.12,4x))'
  fmtstr2='('//trim(adjustl(fmtstr2))//'(F16.12,4x))'

  allocate(loadgeoms%cgeom(3*natoms))
  allocate(loadgeoms%igeom(ncoord))
  allocate(loadgeoms%hessian(natoms*3,natoms*3))
  allocate(loadgeoms%freqs(ncoord))
  allocate(loadgeoms%energy(nstates))
  allocate(loadgeoms%bmat(ncoord,3*natoms))
  
  GUNIT=getFLUnit()
  call chdir(outputdir)
  if(isloop)then
    enerfl='energy.all'
    do i=1,nstates
      write(ind,'(i4)')i
      gradfl(i)='cartgrd.drt1.state'//trim(adjustl(ind))//'.all'
    end do
    k=1
    do i=1,nstates
      write(ind,'(i4)')i
      do j=i+1,nstates
        write(jnd,'(i4)')j
        cpfl(k)='cartgrd_total.drt1.state'//trim(adjustl(ind))//'.drt1.stat'//&
                 trim(adjustl(jnd))//'.all'
        k=k+1
      end do
    end do
  else
    enerfl='energy'
    do i=1,nstates
      write(ind,'(i4)')i
      gradfl(i)='cartgrd.drt1.state'//trim(adjustl(ind))
    end do
    k=1
    do i=1,nstates
      write(ind,'(i4)')i
      do j=i+1,nstates
        write(jnd,'(i4)')j
        cpfl(k)='cartgrd_total.drt1.state'//trim(adjustl(ind))//'.drt1.stat'//&
                 trim(adjustl(jnd))
        k=k+1
      end do
    end do
  end if
  !--------------------------------------------
  ! create output files
  open(unit=GUNIT,file=enerfl,status='replace',ACCESS='SEQUENTIAL',action='write',&
          form='FORMATTED',iostat=ios)
  close(GUNIT)
  do i=1,nstates
    open(unit=GUNIT,file=gradfl(i),status='replace',ACCESS='SEQUENTIAL',action='write',&
         form='FORMATTED',iostat=ios)
    close(GUNIT)
  end do
  do i=1,nstates*(nstates-1)/2
    open(unit=GUNIT,file=cpfl(i),status='replace',ACCESS='SEQUENTIAL',action='write',&
         form='FORMATTED',iostat=ios)
    close(GUNIT)
  end do
  ! create output files for diabatic energies and gradients
  if(outputdiab)then
    open(unit=GUNIT,file='d'//enerfl,status='replace',ACCESS='SEQUENTIAL',action='write',&
          form='FORMATTED',iostat=ios)
    close(GUNIT)
    do i=1,nstates
      open(unit=GUNIT,file='d'//gradfl(i),status='replace',ACCESS='SEQUENTIAL',action='write',&
         form='FORMATTED',iostat=ios)
      close(GUNIT)
    end do
    do i=1,nstates*(nstates-1)/2
      open(unit=GUNIT,file='d'//cpfl(i),status='replace',ACCESS='SEQUENTIAL',action='write',&
         form='FORMATTED',iostat=ios)
      close(GUNIT)
    end do
  end if
  !--------------------------------------------
  ! Read in geometries and output energies, gradients and couplings
  !--------------------------------------------
  do i = 1,ngeoms
   write(ind,'(i4)')i+loopst-1

   ! determine geometry input filename
   if(isloop)then
     fname=trim(adjustl(geomfl))//'.'//trim(adjustl(ind))
   else
     fname=trim(adjustl(geomfl))
   end if
   print *,"loading from file"
   ! read in cartesian geometry in COLUMBUS format.  
   call readColGeom(fname,int(1),natoms,atoms,anums,loadgeoms%cgeom,masses)
   ! generate internal geometry and B matrix
   call buildWBMat(loadgeoms%cgeom,loadgeoms%igeom,loadgeoms%bmat,.false.)

   ! generate eigenvectors and energies at current geometry
   call makehmat(loadgeoms%igeom,hmat)
   CALL DSYEVR('V','A','U',nstates,hmat,nstates,dble(0),dble(0),0,0,1D-12,m,&
            loadgeoms%energy,evec,nstates,ISUPPZ,WORK,LWORK,IWORK,LIWORK, INFO )
   
   print *,"Hd for point ",i
   do m=1,nstates
     print *,hmat(m,:)
   end do

   ! output energies to file   
   open(unit=GUNIT,file=enerfl,access='sequential',form='formatted',&
      status='old',action='write',position='append',iostat=ios)
   write(GUNIT,fmtstr)loadgeoms%energy-eshift
   close(GUNIT)
   if(outputdiab)then
    do j=1,nstates
      hmat(j,j)=hmat(j,j)-eshift
    end do
    open(unit=GUNIT,file='d'//enerfl,access='sequential',form='formatted',&
      status='old',action='write',position='append',iostat=ios)
    write(GUNIT,fmtstr2)hmat
    close(GUNIT)
   end if

   ! generate gradients of Hd in internal
   call makedhmat(loadgeoms%igeom,dhmat)
   do m=1,ncoord
     igrads(m,:,:)=matmul(transpose(evec),matmul(dhmat(m,:,:),evec))
   end do!m=1,ncoord

   ! convert gradients and couplings to cartesian coordinates
   cgrads=dble(0)
   do k=1,3*natoms
     do m=1,ncoord
       cgrads(k,:,:)=cgrads(k,:,:)+igrads(m,:,:)*loadgeoms%bmat(m,k)
       if(outputdiab)&
         dcgrads(k,:,:)=dcgrads(k,:,:)+dhmat(m,:,:)*loadgeoms%bmat(m,k)
     end do !m=1,ncoord
   end do !k=1,3*natoms

   ! output gradients and couplings to file
   do m=1,nstates
     open(unit=GUNIT,file=gradfl(m),access='sequential',form='formatted',&
        status='old',action='write',position='append',iostat=ios)
     write(GUNIT,1001)
     write(GUNIT,1001)cgrads(:,m,m)
     close(GUNIT)
     if(outputdiab)then
      open(unit=GUNIT,file='d'//gradfl(m),access='sequential',form='formatted',&
         status='old',action='write',position='append',iostat=ios)
      write(GUNIT,1001)
      write(GUNIT,1001)dcgrads(:,m,m)
      close(GUNIT)
     end if
   end do
   k=1
   do m=1,nstates
     do j=m+1,nstates
       open(unit=GUNIT,file=cpfl(k),access='sequential',form='formatted',&
          status='old',action='write',position='append',iostat=ios)
       write(GUNIT,1001)
       write(GUNIT,1001)cgrads(:,m,j)
       close(GUNIT)
       if(outputdiab)then
        open(unit=GUNIT,file='d'//cpfl(k),access='sequential',form='formatted',&
           status='old',action='write',position='append',iostat=ios)
        write(GUNIT,1001)
        write(GUNIT,1001)dcgrads(:,m,j)
        close(GUNIT)
       end if
       k=k+1
     end do
   end do

  enddo !i=1,ngeoms
 
  call printLoadgeoms()

  deallocate(loadgeoms%cgeom)
  deallocate(loadgeoms%igeom)
  deallocate(loadgeoms%hessian)
  deallocate(loadgeoms%freqs)
  deallocate(loadgeoms%energy)
  deallocate(loadgeoms%bmat)

  return
1001 format(3(2x,E13.6))
end SUBROUTINE loadgeom

!
!
!
!
SUBROUTINE printTitle(jobtype)
  use hddata, only: ncoord
  use progdata,only:eshift,OUTFILE
  IMPLICIT NONE
  INTEGER,INTENT(IN)                        :: jobtype
  CHARACTER(9),dimension(4)                 :: types = (/'MAKESURF ','EXTREMA  ', &
                                                         'LOADGEOM ','TRANSFORM' /)

  open(unit=OUTFILE,file='surfgen.out',access='sequential',form='formatted')
  write(OUTFILE,1000)'-----------------------------------------------------------'
  write(OUTFILE,1000)'                                                           '
  write(OUTFILE,1000)'                     surfgen.global.x                      '
  write(OUTFILE,1000)'                                                           '
  write(OUTFILE,1000)'   * Creates quasi-diabatic Hamiltonian by reproducing     '
  write(OUTFILE,1000)'   ab initio energy gradients and derivative couplings     '
  write(OUTFILE,1000)'   with selected data fitted exactly and the rest in a     '
  write(OUTFILE,1000)'   least-squares sense                                     '
  write(OUTFILE,1000)'                                                           '
  write(OUTFILE,1000)'   * Blocks of Hd are expanded as polynomials of scaled    '
  write(OUTFILE,1000)'   internuclear distance and out-of-plane angle coords     '
  write(OUTFILE,1000)'   that are well-defined globally.                         ' 
  write(OUTFILE,1000)'                                                           '
  write(OUTFILE,1000)'   * Hd is constructed, using projection operators, so     '
  write(OUTFILE,1000)'   that the diabats carry certain irreps of CNPI group     '
  write(OUTFILE,1000)'                                                           '
  write(OUTFILE,1000)'   Xiaolei Zhu,  2010                                      '
  write(OUTFILE,1000)'   Department of Chemistry, Johns Hopkins University       '
  write(OUTFILE,1000)'   based on SURFGEN.X, Michael Schuurman,  2008            '
  write(OUTFILE,1000)'-----------------------------------------------------------'
  write(OUTFILE,1000)''
  write(OUTFILE,1000)'  jobtype = '//types(jobtype)
  write(OUTFILE,1000)''
  write(OUTFILE,1000)'  Energy shift'
  write(OUTFILE,1002)eshift
  write(OUTFILE,1000)''

1000 format(72a)
1002 format(6(3x,F15.8))
end SUBROUTINE printTitle

! output surface to file
!
!
!
!
SUBROUTINE printLoadgeoms()
  use hddata, only:nstates,ncoord
  use progdata, only: OUTFILE,AU2CM1,nmin,nept,nmex,eshift
  IMPLICIT NONE
  INTEGER                             :: i,j,ioff
  DOUBLE PRECISION,dimension(nstates) :: eners

  ioff = 0
  write(OUTFILE,1000)


  ! print minimum data
  do i = 1,nmin
   do j = 1,nstates
!    eners(j) = (loadgeoms(i)%energy(j)+eshift)*AU2CM1
   enddo
   write(OUTFILE,1001)i
   write(OUTFILE,1004)eners
!   write(OUTFILE,1005)loadgeoms(i)%igeom
!   write(OUTFILE,1006)loadgeoms(i)%freqs
!   write(OUTFILE,1007)0.5*sum(loadgeoms(i)%freqs)
  enddo

  ! print energy point data
  ioff = ioff + nmin
  do i = 1,nept
   do j = 1,nstates
!    eners(j) = (loadgeoms(i+ioff)%energy(j)+eshift)*AU2CM1
   enddo
   write(OUTFILE,1002)i
   write(OUTFILE,1004)eners
!   write(OUTFILE,1005)loadgeoms(i+ioff)%igeom
  enddo

  ! print out intersection data
  ioff = ioff + nept
  do i = 1,nmex
   do j = 1,nstates
!    eners(j) = (loadgeoms(i+ioff)%energy(j)+eshift)*AU2CM1
   enddo
   write(OUTFILE,1003)i
   write(OUTFILE,1004)eners
!   write(OUTFILE,1005)loadgeoms(i+ioff)%igeom
  enddo

  ! print out vibronic basis data
  ioff = ioff + nmex
! do i = 1,nbasis
!  if(i.eq.1)then
!   write(OUTFILE,1008)
!  else
!   write(OUTFILE,1009)
!  endif
!
!  write(OUTFILE,1005)loadgeoms(i+ioff)%igeom
!  write(OUTFILE,1006)loadgeoms(i+ioff)%freqs

! enddo


  return
1000 format(/,2x,'-----------------------------------------------------',/, &
            2x,'--------     Geometries Loaded from File     --------',/, &
            2x,'-----------------------------------------------------',/)
1001 format(/,2x,'MINIMUM ',i3,' --------------------')
1002 format(/,2x,'ENERGY POINT ',i3,'----------------')
1003 format(/,2x,'CONICAL INTERSECTION ',i3,'--------')
1004 format(2x,'Energies (cm-1): ',/,9(F10.2,1x))
1005 format(2x,'Geometry:',/,9(F10.6,1x))
1006 format(2x,'Frequencies (cm-1):',/,9(F10.2,1x))
1007 format(2x,'ZPVE (cm-1):',/,F10.2)
1008 format(/,2x,'Vibronic Basis ----------------------')
1009 format(/,2x,'Vibronic Reference State ------------')
end SUBROUTINE printLoadgeoms


!
!
!
SUBROUTINE cleanup()
  use hddata, only: cleanHdData
  use progdata
  use CNPI
  IMPLICIT NONE
  INTEGER                 :: i,j

  if(allocated(pmtList))deallocate(pmtList)
  if(allocated(subPerm))deallocate(subPerm)
  if(allocated(nSubPerm))deallocate(nSubPerm)
  if(allocated(coordPerm))deallocate(coordPerm)
  if(allocated(sgnCPerm))deallocate(sgnCPerm)

  CALL deallocIrreps()
  call deallocPCycle()
  CALL cleanHdData
  
  if(allocated(CoordSet))then
    do i=1,nCoordSets
      if(allocated(CoordSet(i)%iCoord))deallocate(CoordSet(i)%iCoord)
      if(allocated(CoordSet(i)%iCoord))deallocate(CoordSet(i)%Coef)
    end do
    deallocate(CoordSet)
  end if!(allocated(CoordSet))

  write(OUTFILE,1000)
  close(OUTFILE)
  return
1000 format(/,/,'  ---------------- EXECUTION COMPLETE -----------------',/)
end SUBROUTINE cleanup

! read COLUMBUS geom file and obtain geometry and atom info
SUBROUTINE readColGeom(gfile,ngeoms,na,atoms,anums,cgeom,masses)
  use hddata, only:  getFLUnit
  IMPLICIT NONE
  CHARACTER(72),INTENT(IN)                              :: gfile
  INTEGER,INTENT(IN)                                    :: na,ngeoms
  CHARACTER(3),dimension(na),INTENT(INOUT)              :: atoms
  DOUBLE PRECISION,dimension(na),INTENT(INOUT)          :: anums,masses
  DOUBLE PRECISION,dimension(3*na,ngeoms),INTENT(INOUT) :: cgeom
  INTEGER                                               :: i,j,k,GUNIT,ios

  GUNIT=getFLUnit()
  open(unit=GUNIT,file=trim(adjustl(gfile)),access='sequential',form='formatted',&
      status='old',action='read',position='rewind',iostat=ios)
  if(ios/=0)then
    print *,"gfile = [", trim(adjustl(gfile)),"]"
    stop"readColGeom: cannot open file for read"
  end if
  do i = 1,ngeoms
   do j = 1,na
    read(GUNIT,*)atoms(j),anums(j),(cgeom(3*(j-1)+k,i),k=1,3),masses(j)
   enddo
  enddo
  close(GUNIT)

  return
END SUBROUTINE readColGeom

! output COLUMBUS geom file
SUBROUTINE writeColGeom(gfile,na,atoms,anums,cgeom,masses)
  IMPLICIT NONE
  CHARACTER(72),INTENT(IN)                       :: gfile
  INTEGER,INTENT(IN)                             :: na
  CHARACTER(3),dimension(na),INTENT(INOUT)       :: atoms
  DOUBLE PRECISION,dimension(na),INTENT(INOUT)   :: anums,masses
  DOUBLE PRECISION,dimension(3*na),INTENT(INOUT) :: cgeom
  INTEGER                                        :: i,j,GUNIT

  GUNIT=11

  open(unit=GUNIT,file=trim(adjustl(gfile)),access='sequential',form='formatted')
  rewind(GUNIT)
  do i = 1,na
   write(GUNIT,1000)adjustl(atoms(i)),anums(i),(cgeom((i-1)*3+j),j=1,3),masses(i)
  enddo

  close(GUNIT)

  return
1000 format(1x,a3,2x,f4.0,1x,3(f13.8,1x),2x,f12.8)
END SUBROUTINE writeColGeom

!
!
!
!
SUBROUTINE readEner(efile,ngeoms,ne,eners)
  use hddata, only: getFLUnit
  IMPLICIT NONE
  CHARACTER(72),INTENT(IN)                              :: efile
  INTEGER,INTENT(IN)                                    :: ngeoms,ne
  DOUBLE PRECISION,dimension(ne,ngeoms),INTENT(INOUT)   :: eners
  INTEGER                                               :: i,j,EUNIT,ios

  EUNIT=getFLUnit()
  open(unit=EUNIT,file=trim(adjustl(efile)),access='sequential',form='formatted',&
    position='rewind',action='read',status='old',iostat=ios)
  if(ios/=0)stop'readEner: cannot open file for read'
  do i = 1,ngeoms
   read(EUNIT,*)(eners(j,i),j=1,ne)
  enddo
  close(EUNIT)
END SUBROUTINE readEner

!
!
!
SUBROUTINE readGrads(gfile,ngrads,na,cgrads)
  use hddata, only: getFLUnit
  IMPLICIT NONE
  CHARACTER(72),INTENT(IN)                              :: gfile
  INTEGER,INTENT(IN)                                    :: ngrads,na
  DOUBLE PRECISION,dimension(3*na,ngrads),INTENT(INOUT) :: cgrads
  INTEGER                                               :: i,j,k,GUNIT,ios
  GUNIT=getFLUnit()
  open(unit=GUNIT,file=trim(adjustl(gfile)),access='sequential',form='formatted',&
   action='read',position='rewind',status='old',iostat=ios)
  if(ios/=0)stop'readGrads:  cannot open file for read'
  do i = 1,ngrads
!   read(GUNIT,*)scr
   do j = 1,na
    read(GUNIT,*)(cgrads(3*(j-1)+k,i),k=1,3)
   enddo
  enddo
  close(GUNIT)
END SUBROUTINE readGrads

!
!
!
!
SUBROUTINE readHessian(gfile,nrc,hess)
  IMPLICIT NONE
  CHARACTER(72),INTENT(IN)                                :: gfile
  INTEGER,INTENT(IN)                                      :: nrc
  DOUBLE PRECISION,dimension(nrc*(nrc+1)/2),INTENT(INOUT) :: hess
  INTEGER                                                 :: i,GUNIT,ileft,nread,ndone

  GUNIT=11
  ndone = 0
  ileft = nrc*(nrc+1)/2
  open(unit=GUNIT,file=trim(adjustl(gfile)),access='sequential',form='formatted')
  do
   if(ileft.eq.0)EXIT
   nread = min(ileft,10)
   read(GUNIT,1000)(hess(ndone+i),i=1,nread)
   ndone = ndone + nread
   ileft = ileft - nread
  enddo
  close(GUNIT)

  return
1000 format(10(F10.6))
end SUBROUTINE readHessian
!
!
!
!
FUNCTION filename(s1,s2,suffix)
  use progdata, only: usefij
  IMPLICIT NONE
  INTEGER,INTENT(IN)          :: s1,s2
  CHARACTER(10),INTENT(IN)    :: suffix
  CHARACTER(72)               :: filename
  CHARACTER(1)                :: st1,st2

  write(st1,'(i1)')s1
  write(st2,'(i1)')s2

  if(s1.eq.s2)then
   filename = 'cartgrd.drt1.state'//st1//trim(adjustl(suffix))
  else
   if(usefij)then
     filEname = 'cartgrd_total.drt1.state'//st1//'.drt1.state'//st2//trim(adjustl(suffix))
   else
     filename = 'cartgrd.nad.drt1.state'//st1//'.drt1.state'//st2//trim(adjustl(suffix))
   end if
  endif

  filename = trim(adjustl(filename))
END FUNCTION filename


!printMatrix prints a matrix of double precision numbers to file
!ofile   :    output file
!rlabs   :    array(nr) of row label strings
!clabs   :    array(nc) of col label strings
!pcols   :    max number of columns displayed in a line
!nr      :    number of rows
!nc      :    number of columns
!mat     :    matrix to print
!fld,dcml:    printing format (F($fld).($dcml))
SUBROUTINE printMatrix(ofile,rlabs,clabs,pcols,nr,nc,mat,fld,dcml)
  IMPLICIT NONE
  INTEGER,INTENT(IN)                     :: ofile,pcols,nr,nc,fld,dcml
  CHARACTER(16),dimension(nr),INTENT(IN) :: rlabs
  CHARACTER(16),dimension(nc),INTENT(IN) :: clabs
  DOUBLE PRECISION,dimension(nr,nc),INTENT(IN) :: mat
  INTEGER                                :: i,j,k,ilo,ihi,nbatch
  INTEGER                                :: rlen,clen,flen,lspace,rspace
  CHARACTER(4)                           :: rlstr,clstr,lstr,rstr
  CHARACTER(72)                          :: FMT1,FMT2,FMT3,FMT4

  flen = fld
  rlen = 0
  clen = 0
  do i = 1,nr
   j = len_trim(rlabs(i))
   if(j.gt.rlen)rlen = j
  enddo
  do i = 1,nc
   j = len_trim(clabs(i))
   if(j.gt.clen)clen = j
  enddo

  write(rlstr,'(i4)')rlen
  write(clstr,'(i4)')clen
  FMT1 = '(/,'//trim(adjustl(rlstr))//'x)'
  FMT2 = '(a'//trim(adjustl(rlstr))//')'
  rspace = int((flen-clen)/2.)
  lspace = flen - clen - rspace
  if(rspace.lt.0)rspace=0
  if(lspace.lt.0)lspace=1
  write(lstr,'(i4)')lspace
  write(rstr,'(i4)')rspace
  FMT3 = '('//trim(adjustl(lstr))//'x,a'//trim(adjustl(clstr))//','//trim(adjustl(rstr))//'x)'
  write(lstr,'(i4)')flen-1
  write(rstr,'(i4)')dcml
  FMT4 = '(x,F'//trim(adjustl(lstr))//'.'//trim(adjustl(rstr))//')'

  nbatch = Ceiling(1.*nc/pcols)
  do i = 1,nbatch
   ilo = pcols*(i-1)+1
   ihi = min(pcols*i,nc)
   write(ofile,trim(FMT1),advance='no')
   do j = ilo,ihi
    write(ofile,trim(FMT3),advance='no')clabs(j)
   enddo
   write(ofile,1001,advance='no')
   do j = 1,nr
    write(ofile,trim(FMT2),advance='no')rlabs(j)
    do k=ilo,ihi
     write(ofile,trim(FMT4),advance='no')mat(j,k)
    enddo
    write(ofile,1001,advance='no')
   enddo
  enddo

  return
1001 format(/)
end SUBROUTINE printMatrix

