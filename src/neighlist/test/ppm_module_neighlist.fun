test_suite ppm_module_neighlist



#ifdef __MPI
    INCLUDE "mpif.h"
#endif

integer, parameter              :: debug = 0
integer, parameter              :: mk = kind(1.0d0) !kind(1.0e0)
real(mk),parameter              :: pi = 3.1415926535897931_mk
real(mk),parameter              :: skin = 0._mk
integer,parameter               :: ndim=2
integer,parameter               :: pdim=2
integer                         :: decomp,assig,tolexp
real(mk)                        :: tol,min_rcp,max_rcp
integer                         :: info,comm,rank,nproc
integer                         :: topoid
integer                         :: np = 100000
integer                         :: mp
integer                         :: newnp
real(mk),dimension(:,:),pointer :: xp => NULL()
real(mk),dimension(:  ),pointer :: rcp => NULL()
real(mk),dimension(:,:),pointer :: wp => NULL()
real(mk),dimension(:  ),pointer :: min_phys => NULL()
real(mk),dimension(:  ),pointer :: max_phys => NULL()
real(mk),dimension(:  ),pointer :: h => NULL()
real(mk),dimension(:  ),pointer :: p_h => NULL()
real(mk),dimension(:  ),pointer :: len_phys => NULL()
real(mk),dimension(:  ),pointer :: ghostlayer => NULL()
integer, dimension(:  ),pointer :: ghostsize => NULL()
integer                         :: i,j,k,sum1,sum2
integer                         :: p_i
integer, dimension(6)           :: bcdef
real(mk),dimension(:  ),pointer :: cost => NULL()
integer, dimension(:  ),pointer :: nm => NULL()
integer                         :: seedsize
integer,  dimension(:),allocatable :: seed
real(mk), dimension(:),allocatable :: randnb
integer                          :: isymm = 0
logical                          :: lsymm = .false.,ok
real(mk)                         :: t0,t1,t2,t3
real(mk)                         :: eps

    init

        use ppm_module_typedef
        use ppm_module_init
        
        allocate(min_phys(ndim),max_phys(ndim),len_phys(ndim),&
            &         ghostsize(ndim),ghostlayer(2*ndim),&
            &         nm(ndim),h(ndim),p_h(ndim),stat=info)
        
        min_phys(1:ndim) = 0.0_mk
        max_phys(1:ndim) = 1.0_mk
        len_phys(1:ndim) = max_phys-min_phys
        ghostsize(1:ndim) = 2
        ghostlayer(1:2*ndim) = max_rcp
        bcdef(1:6) = ppm_param_bcdef_periodic
        
        eps = epsilon(1.0_mk)
        tolexp = int(log10(epsilon(1.0_mk)))
        
        nullify(xp,rcp,wp)

#ifdef __MPI
        comm = mpi_comm_world
        call mpi_comm_rank(comm,rank,info)
        call mpi_comm_size(comm,nproc,info)
#else
        rank = 0
        nproc = 1
#endif
        call ppm_init(ndim,mk,tolexp,0,debug,info,99)

    end init


    finalize
        use ppm_module_finalize

        call ppm_finalize(info)

        deallocate(min_phys,max_phys,len_phys,ghostsize,nm)

    end finalize


    setup

        call random_seed(size=seedsize)
        allocate(seed(seedsize))
        allocate(randnb((1+ndim)*np),stat=info)
        do i=1,seedsize
            seed(i)=10+i*i*(rank+1)
        enddo
        call random_seed(put=seed)
        call random_number(randnb)
        
        allocate(xp(ndim,np),rcp(np),wp(pdim,np),stat=info)

    end setup
        

    teardown
        
        deallocate(xp,rcp,wp,stat=info)
        deallocate(seed,randnb)

    end teardown

    test symBC_neighlist
        ! tests symmetric boundary conditions and ghost get
        use ppm_module_typedef
        use ppm_module_mktopo
        use ppm_module_map
        use ppm_module_topo_check
        use ppm_module_util_dbg

        integer                         :: npart = 4
        integer                         :: newnpart
        integer                         :: mpart
        integer                         :: oldip,ip = -1
        real(mk),dimension(:,:),pointer :: p => NULL()
        real(mk),dimension(ndim)        :: cp
        real(mk), parameter             :: gl = 0.1_mk
        real(mk), parameter             :: skin = 0.05_mk
        integer, dimension(:),pointer   :: nvlist => NULL()
        integer, dimension(:,:),pointer :: vlist => NULL()

        allocate(p(ndim,npart))
        p(1,1) = 0.05_mk
        p(2,1) = 0.5_mk
        p(1,2) = 0.5_mk
        p(2,2) = 0.05_mk
        p(1,3) = 0.05_mk
        p(2,3) = 0.05_mk
        p(1,4) = 0.5_mk
        p(2,4) = 0.95_mk

        bcdef(1:6) = ppm_param_bcdef_symmetry
        nullify(nvlist,vlist)

        !----------------
        ! make topology
        !----------------
        decomp = ppm_param_decomp_cuboid
        !decomp = ppm_param_decomp_xpencil
        assig  = ppm_param_assign_internal

        topoid = 0

        call ppm_mktopo(topoid,p,npart,decomp,assig,min_phys,max_phys,bcdef, &
        &               gl+skin,cost,info)

        call ppm_map_part_global(topoid,p,npart,info)
        call ppm_map_part_send(npart,newnpart,info)
        call ppm_map_part_pop(p,ndim,npart,newnpart,info)
        npart=newnpart


        call ppm_map_part_ghost_get(topoid,p,ndim,npart,0,gl+skin,info)
        call ppm_map_part_send(npart,mpart,info)
        call ppm_map_part_pop(p,ndim,npart,mpart,info)
        
        call ppm_topo_check(topoid,p,npart,ok,info)
        !call ppm_dbg_print_d(topoid,gl+skin,1,1,info,p,npart,mpart)
        
        call ppm_neighlist_vlist(topoid,p,mpart,gl,skin,.TRUE.,&
        &                        vlist,nvlist,info)

        !do i=1,mpart
        !    print *,i,p(:,i)
        !    do j=1,nvlist(i)
        !        print *,'    ',vlist(j,i)
        !    enddo
        !enddo

        ! do the tests
        ! p(1)
        cp(1) = -0.05_mk
        cp(2) = 0.5_mk
        ip = -1
        do i=npart+1,mpart
            if ((abs(p(1,i)-cp(1)).lt.eps).and.&
            &   (abs(p(2,i)-cp(2)).lt.eps)) then
                ip = i
                exit
            endif
        enddo
        assert_false(ip.eq.-1)
        assert_true((vlist(1,1).eq.ip).or.(vlist(1,ip).eq.1))

        ! p(2)
        cp(1) = 0.5_mk
        cp(2) = -0.05_mk
        ip = -1
        do i=npart+1,mpart
            if ((abs(p(1,i)-cp(1)).lt.eps).and.&
            &   (abs(p(2,i)-cp(2)).lt.eps)) then
                ip = i
                exit
            endif
        enddo
        assert_false(ip.eq.-1)
        assert_true((vlist(1,2).eq.ip).or.(vlist(1,ip).eq.2))
        
        ! p(3)
        cp(1) = 0.05_mk
        cp(2) = -0.05_mk
        ip = -1
        do i=npart+1,mpart
            if ((abs(p(1,i)-cp(1)).lt.eps).and.&
            &   (abs(p(2,i)-cp(2)).lt.eps)) then
                ip = i
                exit
            endif
        enddo
        assert_false(ip.eq.-1)
        ok = (vlist(1,3).eq.ip).or.&
        &    (vlist(2,3).eq.ip).or.&
        &    (vlist(1,ip).eq.3).or.&
        &    (vlist(2,ip).eq.3)
        assert_true(ok)
        cp(1) = -0.05_mk
        cp(2) = 0.05_mk
        ip = -1
        do i=npart+1,mpart
            if ((abs(p(1,i)-cp(1)).lt.eps).and.&
            &   (abs(p(2,i)-cp(2)).lt.eps)) then
                ip = i
                exit
            endif
        enddo
        assert_false(ip.eq.-1)
        ok = (vlist(1,3).eq.ip).or.&
        &    (vlist(2,3).eq.ip).or.&
        &    (vlist(1,ip).eq.3).or.&
        &    (vlist(2,ip).eq.3)
        assert_true(ok)
        cp(1) = -0.05_mk
        cp(2) = -0.05_mk
        ip = -1
        do i=npart+1,mpart
            if ((abs(p(1,i)-cp(1)).lt.eps).and.&
            &   (abs(p(2,i)-cp(2)).lt.eps)) then
                ip = i
                exit
            endif
        enddo
        assert_false(ip.eq.-1)
        ok = (vlist(1,3).eq.ip).or.&
        &    (vlist(2,3).eq.ip).or.&
        &    (vlist(1,ip).eq.3).or.&
        &    (vlist(2,ip).eq.3)
        assert_true(ok)

        ! p(4)
        cp(1) = 0.5_mk
        cp(2) = 1.05_mk
        ip = -1
        do i=npart+1,mpart
            if ((abs(p(1,i)-cp(1)).lt.eps).and.&
            &   (abs(p(2,i)-cp(2)).lt.eps)) then
                ip = i
                exit
            endif
        enddo
        assert_false(ip.eq.-1)
        assert_true((vlist(1,4).eq.ip).or.(vlist(1,ip).eq.4))


    end test


end test_suite
