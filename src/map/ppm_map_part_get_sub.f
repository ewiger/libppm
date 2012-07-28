      !-------------------------------------------------------------------------
      !  Subroutine   :               ppm_map_part_get_sub
      !-------------------------------------------------------------------------
      ! Copyright (c) 2010 CSE Lab (ETH Zurich), MOSAIC Group (ETH Zurich), 
      !                    Center for Fluid Dynamics (DTU)
      !
      !
      ! This file is part of the Parallel Particle Mesh Library (PPM).
      !
      ! PPM is free software: you can redistribute it and/or modify
      ! it under the terms of the GNU Lesser General Public License 
      ! as published by the Free Software Foundation, either 
      ! version 3 of the License, or (at your option) any later 
      ! version.
      !
      ! PPM is distributed in the hope that it will be useful,
      ! but WITHOUT ANY WARRANTY; without even the implied warranty of
      ! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
      ! GNU General Public License for more details.
      !
      ! You should have received a copy of the GNU General Public License
      ! and the GNU Lesser General Public License along with PPM. If not,
      ! see <http://www.gnu.org/licenses/>.
      !
      ! Parallel Particle Mesh Library (PPM)
      ! ETH Zurich
      ! CH-8092 Zurich, Switzerland
      !-------------------------------------------------------------------------

#if    __KIND == __SINGLE_PRECISION
      SUBROUTINE ppm_map_part_get_sub_s(topoid,isublist,nsublist,xp,Npart,info)
#elif  __KIND == __DOUBLE_PRECISION
      SUBROUTINE ppm_map_part_get_sub_d(topoid,isublist,nsublist,xp,Npart,info)
      !!! This routine maps (retrieves) the particles on the sub domains and
      !!! topology listed in the input list.
      !!!
      !!! [WARNING]
      !!! this routine was NOT tested in serial !
#endif

      !-------------------------------------------------------------------------
      !  Modules
      !-------------------------------------------------------------------------
      USE ppm_module_data
      USE ppm_module_substart
      USE ppm_module_substop
      USE ppm_module_error
      USE ppm_module_alloc
      USE ppm_module_check_id
      IMPLICIT NONE
#if    __KIND == __SINGLE_PRECISION  | __KIND_AUX == __SINGLE_PRECISION
      INTEGER, PARAMETER :: MK = ppm_kind_single
#else
      INTEGER, PARAMETER :: MK = ppm_kind_double
#endif
      !-------------------------------------------------------------------------
      !  Includes
      !-------------------------------------------------------------------------
#ifdef __MPI
      INCLUDE 'mpif.h'
#endif
      !-------------------------------------------------------------------------
      !  Arguments
      !-------------------------------------------------------------------------
      REAL(MK), DIMENSION(:,:), INTENT(IN   ) :: xp
      !!! Particle coordinates
      INTEGER , DIMENSION(:)  , INTENT(IN   ) :: isublist
      !!! List of sub domain in topology
      INTEGER                 , INTENT(IN   ) :: nsublist
      !!! Length of list(:)
      INTEGER                 , INTENT(IN   ) :: Npart
      !!! Number of particles
      INTEGER                 , INTENT(IN   ) :: topoid
      !!! Topology ID
      INTEGER                 , INTENT(  OUT) :: info
      !!! Returns 0 upon success
      !-------------------------------------------------------------------------
      !  Local variables
      !-------------------------------------------------------------------------
      INTEGER, DIMENSION(3)               :: ldu
      INTEGER                             :: i,j,k,isub
      INTEGER                             :: nsublist1,nsublist2,nghost
      INTEGER                             :: nghostplus
      INTEGER                             :: ipart,sendrank,recvrank
      INTEGER                             :: iopt,iset,ibuffer
      INTEGER                             :: tag1,tag2
      INTEGER, DIMENSION(:), POINTER      :: bcdef   => NULL()
      REAL(MK), DIMENSION(:,:), POINTER   :: min_sub => NULL()
      REAL(MK), DIMENSION(:,:), POINTER   :: max_sub => NULL()
      REAL(MK)                            :: t0
      LOGICAL                             :: valid
#ifdef __MPI
      INTEGER, DIMENSION(MPI_STATUS_SIZE) :: status
#endif
      TYPE(ppm_t_topo)      , POINTER     :: topo => NULL()
      !-------------------------------------------------------------------------
      !  Externals
      !-------------------------------------------------------------------------

      !-------------------------------------------------------------------------
      !  Initialise
      !-------------------------------------------------------------------------
      CALL substart('ppm_map_part_get_sub',t0,info)
      bcdef => topo%bcdef(:)

      !-------------------------------------------------------------------------
      !  Check arguments
      !-------------------------------------------------------------------------
      IF (ppm_debug .GT. 0) THEN
        CALL check
        IF (info .NE. 0) GOTO 9999
      ENDIF
      topo => ppm_topo(topoid)%t
      !-------------------------------------------------------------------------
      !  Now if we have only one processor skip the rest
      !-------------------------------------------------------------------------
      IF (ppm_nproc.EQ.1) THEN
         GOTO 9999
      ENDIF

      !-------------------------------------------------------------------------
      !  Moreover, if we are not using MPI we can skip the rest of the source
      !-------------------------------------------------------------------------
#ifdef __MPI

      !-------------------------------------------------------------------------
      !  Checking precision and pointing tree data to correct variables
      !-------------------------------------------------------------------------
#if   __KIND == __SINGLE_PRECISION
      min_sub      => topo%min_subs
      max_sub      => topo%max_subs
#else
      min_sub      => topo%min_subd
      max_sub      => topo%max_subd
#endif

      !-------------------------------------------------------------------------
      !  Save the map type for the subsequent calls
      !  this mapping is a ghost get mapping: the (real) particle on the
      !  processor is NOT touched by this mapping - the ghosts are just
      !  added to the end of the particle list
      !-------------------------------------------------------------------------
      ppm_map_type = ppm_param_map_ghost_get

      !-------------------------------------------------------------------------
      !  Allocate memory for the pointers to the particles that will be send
      !  and received from and to a processor. The ppm_recvbuffer is NOT used
      !  in this routine, but initialized from the precv() array in the routine
      !  ppm_map_part_send().
      !-------------------------------------------------------------------------
      ldu(1) = ppm_nproc + 1
      iopt   = ppm_param_alloc_grow
      CALL ppm_alloc(ppm_psendbuffer,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',     &
     &        'global send buffer pointer PPM_PSENDBUFFER',__LINE__,info)
          GOTO 9999
      ENDIF

      ldu(1) = Npart
      CALL ppm_alloc(ppm_buffer2part,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',     &
     &        'buffer-to-particles map PPM_BUFFER2PART',__LINE__,info)
          GOTO 9999
      ENDIF

      !-------------------------------------------------------------------------
      !  Store the number of buffer entries (this is the first)
      !-------------------------------------------------------------------------
      ppm_buffer_set = 1

      !-------------------------------------------------------------------------
      !  Allocate memory for the field registers that holds the dimension and
      !  type of the data
      !-------------------------------------------------------------------------
      ldu(1) = ppm_buffer_set
      CALL ppm_alloc(ppm_buffer_dim ,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',     &
     &        'buffer dimensions PPM_BUFFER_DIM',__LINE__,info)
          GOTO 9999
      ENDIF
      CALL ppm_alloc(ppm_buffer_type,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',     &
     &        'buffer types PPM_BUFFER_TYPE',__LINE__,info)
          GOTO 9999
      ENDIF

      !-------------------------------------------------------------------------
      !  Store the dimension and type
      !-------------------------------------------------------------------------
      ppm_buffer_dim(ppm_buffer_set)  = ppm_dim
#if    __KIND == __SINGLE_PRECISION
      ppm_buffer_type(ppm_buffer_set) = ppm_kind_single
#else
      ppm_buffer_type(ppm_buffer_set) = ppm_kind_double
#endif

      !-------------------------------------------------------------------------
      !  (Re)allocate memory for the buffer (need not save the contents of the
      !  buffer since this is a global map).
      !-------------------------------------------------------------------------
      ldu(1) = ppm_dim*Npart
      IF (ppm_kind.EQ.ppm_kind_double) THEN
         CALL ppm_alloc(ppm_sendbufferd,ldu,iopt,info)
      ELSE
         CALL ppm_alloc(ppm_sendbuffers,ldu,iopt,info)
      ENDIF
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',     &
     &        'global send buffer PPM_SENDBUFFER',__LINE__,info)
          GOTO 9999
      ENDIF

      !-------------------------------------------------------------------------
      !  Allocate memory for the sendlist
      !-------------------------------------------------------------------------
      ppm_nsendlist = ppm_nproc
      ppm_nrecvlist = ppm_nproc
      ldu(1)        = ppm_nsendlist
      CALL ppm_alloc(ppm_isendlist,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',     &
     &        'send list PPM_ISENDLIST',__LINE__,info)
          GOTO 9999
      ENDIF
      CALL ppm_alloc(ppm_irecvlist,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',     &
     &        'receive list PPM_IRECVLIST',__LINE__,info)
          GOTO 9999
      ENDIF

      !-------------------------------------------------------------------------
      !  Before we start, copy the isublist into a temporary array
      !-------------------------------------------------------------------------
      ldu(1) = nsublist
      iopt   = ppm_param_alloc_fit
      CALL ppm_alloc(ilist1,ldu,iopt,info)
      CALL ppm_alloc(ilist2,ldu,iopt,info)
      CALL ppm_alloc(ilist3,ldu,iopt,info)
      CALL ppm_alloc(ilist4,ldu,iopt,info)
      ilist1 = isublist
      nlist1 = nsublist
      tag1   = 100
      tag2   = 200
      !-------------------------------------------------------------------------
      !   Initialize the buffers
      !-------------------------------------------------------------------------
      sendrank           = ppm_rank - 1
      recvrank           = ppm_rank + 1
      ppm_psendbuffer(1) = 1
      ppm_nsendlist      = 0
      ppm_nrecvlist      = 0
      iset               = 0
      ibuffer            = 0

      !-------------------------------------------------------------------------
      !  Since we skip the local processor entirely, increment the pointers once
      !-------------------------------------------------------------------------
      sendrank                     = sendrank + 1
      recvrank                     = recvrank - 1
      ppm_nsendlist                = ppm_nsendlist + 1
      ppm_isendlist(ppm_nsendlist) = sendrank
      ppm_nrecvlist                = ppm_nrecvlist + 1
      ppm_irecvlist(ppm_nrecvlist) = recvrank
      ppm_psendbuffer(2)           = ppm_psendbuffer(1)

      !-------------------------------------------------------------------------
      !  Loop over all processors but skip the processor itself
      !-------------------------------------------------------------------------
      DO i=2,ppm_nproc
         !----------------------------------------------------------------------
         !  compute the next processor
         !----------------------------------------------------------------------
         sendrank = sendrank + 1
         IF (sendrank.GT.ppm_nproc-1) sendrank = sendrank - ppm_nproc
         recvrank = recvrank - 1
         IF (recvrank.LT.          0) recvrank = recvrank + ppm_nproc

         !----------------------------------------------------------------------
         !  Store the processor to which we will send to
         !----------------------------------------------------------------------
         ppm_nsendlist                = ppm_nsendlist + 1
         ppm_isendlist(ppm_nsendlist) = sendrank

         !----------------------------------------------------------------------
         !  Store the processor to which we will recv from
         !----------------------------------------------------------------------
         ppm_nrecvlist                = ppm_nrecvlist + 1
         ppm_irecvlist(ppm_nrecvlist) = recvrank

         !----------------------------------------------------------------------
         !  Loop over the entire list of subs that we need on topoid
         !----------------------------------------------------------------------
         nlist2 = 0
         nlist3 = 0
         DO j=1,nlist1
            !-------------------------------------------------------------------
            !  Check if they belong to the processor from where we will receive
            !  data
            !-------------------------------------------------------------------
            IF (topo%sub2proc(ilist1(j)).EQ.recvrank) THEN
               !----------------------------------------------------------------
               !  If yes, then store it in the local receive list (ilist3)
               !----------------------------------------------------------------
               nlist3         = nlist3 + 1
               ilist3(nlist3) = ilist1(j)
            ELSE
               !----------------------------------------------------------------
               !  otherwise store the sub in the second list to be swapped later
               !----------------------------------------------------------------
               nlist2         = nlist2 + 1
               ilist2(nlist2) = ilist1(j)
            ENDIF
         ENDDO

         !----------------------------------------------------------------------
         !  Swap the lists
         !----------------------------------------------------------------------
         ilist1 = ilist2
         nlist1 = nlist2

         !----------------------------------------------------------------------
         !  Now send the list of data we need to the recvrank processor and
         !  receive the request from the sendrank processor for data we have
         !  to provide. Notice: the first part of the envelope is the SEND part
         !  so we send to the recvlist what we need
         !----------------------------------------------------------------------
         CALL MPI_SendRecv(nlist3,1,MPI_INTEGER,recvrank,tag1, &
     &                     nlist4,1,MPI_INTEGER,sendrank,tag1, &
     &                     ppm_comm,status,info)

         !----------------------------------------------------------------------
         !  Reallocate if needed the (partial) list (ilist4) of subs that we
         !  have and should send to sendrank
         !----------------------------------------------------------------------
         iopt   = ppm_param_alloc_grow
         ldu(1) = nlist4
         CALL ppm_alloc(ilist4,ldu,iopt,info)
         IF (info.NE.0) THEN
             info = ppm_error_fatal
             CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub', &
     &           'allocation of ilist4 failed',__LINE__,info)
             GOTO 9999
         ENDIF
         !----------------------------------------------------------------------
         !  and receive the data
         !----------------------------------------------------------------------
         CALL MPI_SendRecv(ilist3,nlist3,MPI_INTEGER,recvrank,tag2, &
     &                     ilist4,nlist4,MPI_INTEGER,sendrank,tag2, &
     &                     ppm_comm,status,info)

         !----------------------------------------------------------------------
         !  Reallocate to make sure we have enough memory in the
         !  ppm_buffer2part and ppm_sendbuffers/d; we can at most send all our
         !  particles, so we increment the buffer with Npart
         !----------------------------------------------------------------------
         iopt   = ppm_param_alloc_grow_preserve
         ldu(1) = ibuffer + Npart*ppm_dim
         IF (ppm_kind.EQ.ppm_kind_double) THEN
            CALL ppm_alloc(ppm_sendbufferd,ldu,iopt,info)
         ELSE
            CALL ppm_alloc(ppm_sendbuffers,ldu,iopt,info)
         ENDIF
         IF (info .NE. 0) THEN
             info = ppm_error_fatal
             CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',   &
     &           'global send buffer PPM_SENDBUFFER',__LINE__,info)
             GOTO 9999
         ENDIF

         ldu(1) = iset + Npart
         CALL ppm_alloc(ppm_buffer2part,ldu,iopt,info)
         IF (info .NE. 0) THEN
             info = ppm_error_fatal
             CALL ppm_error(ppm_err_alloc,'ppm_map_part_get_sub',   &
     &          'buffer2particles map PPM_BUFFER2PART',__LINE__,info)
             GOTO 9999
         ENDIF

         !----------------------------------------------------------------------
         !  Now we know what to do, and loop over our subs in the ilist4 to
         !  extract the particles
         !----------------------------------------------------------------------
         DO j=1,nlist4
            !-------------------------------------------------------------------
            !  Get the sub id
            !-------------------------------------------------------------------
            isub = ilist4(j)
            IF (ppm_dim.EQ.2) THEN
               !----------------------------------------------------------------
               !  Loop over the particles in 2D
               !----------------------------------------------------------------
               DO k=1,Npart
                  !-------------------------------------------------------------
                  !  and check if they are inside the sub
                  !-------------------------------------------------------------
                  IF (xp(1,k).GE.min_sub(1,isub).AND. &
     &                xp(1,k).LE.max_sub(1,isub).AND. &
     &                xp(2,k).GE.min_sub(2,isub).AND. &
     &                xp(2,k).LE.max_sub(2,isub)) THEN
                      !---------------------------------------------------------
                      !  In the non-periodic case, allow particles that are
                      !  exactly ON an upper EXTERNAL boundary.
                      !---------------------------------------------------------
                      IF((xp(1,k).LT.max_sub(1,isub)      .OR.  &
     &                   (topo%subs_bc(2,isub).EQ.1           .AND.  &
     &                   bcdef(2).NE. ppm_param_bcdef_periodic))    .AND.  &
     &                   (xp(2,k).LT.max_sub(2,isub)      .OR.  &
     &                   (topo%subs_bc(4,isub).EQ.1           .AND.  &
     &                   bcdef(4).NE. ppm_param_bcdef_periodic))) THEN
                         !------------------------------------------------------
                         !  If yes, then store them
                         !------------------------------------------------------
                         iset                  = iset + 1

                         !------------------------------------------------------
                         !  store the ID of the particles
                         !------------------------------------------------------
                         ppm_buffer2part(iset) = k

                         !------------------------------------------------------
                         !  store the particle
                         !------------------------------------------------------
                         IF (ppm_kind.EQ.ppm_kind_double) THEN
#if    __KIND == __SINGLE_PRECISION
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) =      &
     &                          REAL(xp(1,k),ppm_kind_double)
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) =      &
     &                          REAL(xp(2,k),ppm_kind_double)
#else
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) = xp(1,k)
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) = xp(2,k)
#endif
                         ELSE
#if    __KIND == __SINGLE_PRECISION
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) = xp(1,k)
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) = xp(2,k)
#else
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) =      &
     &                          REAL(xp(1,k),ppm_kind_single)
                            ibuffer = ibuffer + 1
                            ppm_sendbufferd(ibuffer) =      &
     &                          REAL(xp(2,k),ppm_kind_single)
#endif
                         ENDIF

                      ENDIF ! for inside/outside
                  ENDIF ! for inside/outside
               ENDDO ! end loop over 2D particles
            ELSE ! else of 2d versus 3d
               !----------------------------------------------------------------
               !  Loop over the particles in 3D
               !----------------------------------------------------------------
               DO k=1,Npart
                  !-------------------------------------------------------------
                  !  and check if they are inside the sub
                  !-------------------------------------------------------------
                  IF (xp(1,k).GE.min_sub(1,isub).AND. &
     &                xp(1,k).LE.max_sub(1,isub).AND. &
     &                xp(2,k).GE.min_sub(2,isub).AND. &
     &                xp(2,k).LE.max_sub(2,isub).AND. &
     &                xp(3,k).GE.min_sub(3,isub).AND. &
     &                xp(3,k).LE.max_sub(3,isub)) THEN
                   !------------------------------------------------------------
                   !  In the non-periodic case, allow particles that are
                   !  exactly ON an upper EXTERNAL boundary.
                   !------------------------------------------------------------
                   IF((xp(1,k).LT.max_sub(1,isub)      .OR. &
     &                (topo%subs_bc(2,isub).EQ.1           .AND. &
     &                bcdef(2).NE. ppm_param_bcdef_periodic))    .AND. &
     &                (xp(2,k).LT.max_sub(2,isub)      .OR. &
     &                (topo%subs_bc(4,isub).EQ.1           .AND. &
     &                bcdef(4).NE. ppm_param_bcdef_periodic))    .AND. &
     &                (xp(3,k).LT.max_sub(3,isub)      .OR. &
     &                (topo%subs_bc(6,isub).EQ.1           .AND. &
     &                bcdef(6).NE. ppm_param_bcdef_periodic))   ) THEN
                     !----------------------------------------------------------
                     !  If yes, then store them
                     !----------------------------------------------------------
                     iset                  = iset + 1

                     !----------------------------------------------------------
                     !  store the ID of the particles
                     !----------------------------------------------------------
                     ppm_buffer2part(iset) = k

                     !----------------------------------------------------------
                     !  store the particle
                     !----------------------------------------------------------
                     IF (ppm_kind.EQ.ppm_kind_double) THEN
#if    __KIND == __SINGLE_PRECISION
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = REAL(xp(1,k),ppm_kind_double)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = REAL(xp(2,k),ppm_kind_double)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = REAL(xp(3,k),ppm_kind_double)
#else
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = xp(1,k)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = xp(2,k)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = xp(3,k)
#endif
                     ELSE
#if    __KIND == __SINGLE_PRECISION
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = xp(1,k)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = xp(2,k)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = xp(3,k)
#else
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = REAL(xp(1,k),ppm_kind_single)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = REAL(xp(2,k),ppm_kind_single)
                        ibuffer = ibuffer + 1
                        ppm_sendbufferd(ibuffer) = REAL(xp(3,k),ppm_kind_single)
#endif
                     ENDIF

                  ENDIF
                  ENDIF
               ENDDO ! end loop over particles
            ENDIF ! endif of 2d/3d
         ENDDO ! end loop over ilist4: the list of subs to send
         !----------------------------------------------------------------------
         !  Update the buffer pointer (ie the current iset ... or the number of
         !  particle we will send to the k-th entry in the icommseq list
         !----------------------------------------------------------------------
         ppm_psendbuffer(i+1) = iset + 1
      ENDDO ! end loop over nproc

      !-------------------------------------------------------------------------
      !  Store the current size of the buffer
      !-------------------------------------------------------------------------
      ppm_nsendbuffer = ibuffer

      !-------------------------------------------------------------------------
      !  Deallocate the memory for the lists
      !-------------------------------------------------------------------------
      iopt = ppm_param_dealloc
      CALL ppm_alloc(ilist1,ldu,iopt,info)
      IF (info.NE.0) THEN
         info = ppm_error_error
         CALL ppm_error(ppm_err_dealloc,'ppm_map_part_get_sub',     &
     &       'ilist1',__LINE__,info)
      ENDIF

      CALL ppm_alloc(ilist2,ldu,iopt,info)
      IF (info.NE.0) THEN
         info = ppm_error_error
         CALL ppm_error(ppm_err_dealloc,'ppm_map_part_get_sub',     &
     &       'ilist2',__LINE__,info)
      ENDIF

      CALL ppm_alloc(ilist3,ldu,iopt,info)
      IF (info.NE.0) THEN
         info = ppm_error_error
         CALL ppm_error(ppm_err_dealloc,'ppm_map_part_get_sub',     &
     &       'ilist3',__LINE__,info)
      ENDIF

      CALL ppm_alloc(ilist4,ldu,iopt,info)
      IF (info.NE.0) THEN
         info = ppm_error_error
         CALL ppm_error(ppm_err_dealloc,'ppm_map_part_get_sub',     &
     &       'ilist4',__LINE__,info)
      ENDIF

      !-------------------------------------------------------------------------
      !  Moreover, if we are not using MPI we can skip the rest of the source
      !-------------------------------------------------------------------------
#endif

      !-------------------------------------------------------------------------
      !  Return
      !-------------------------------------------------------------------------
 9999 CONTINUE
      CALL substop('ppm_map_part_get_sub',t0,info)
      RETURN
      CONTAINS
      SUBROUTINE check
        IF (.NOT. ppm_initialized) THEN
              info = ppm_error_error
              CALL ppm_error(ppm_err_ppm_noinit,'ppm_map_part_get_sub',  &
     &            'Please call ppm_init first!',__LINE__,info)
              GOTO 8888
        ENDIF
        IF (topoid .GT. 0) THEN
              CALL ppm_check_topoid(topoid,valid,info)
              IF (.NOT. valid) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_argument,'ppm_map_part_get_sub',  &
     &                'Invalid topology ID as to_topo specified!',__LINE__,info)
                  GOTO 8888
              ENDIF
        ENDIF
 8888   CONTINUE
      END SUBROUTINE check
#if    __KIND == __SINGLE_PRECISION
      END SUBROUTINE ppm_map_part_get_sub_s
#elif  __KIND == __DOUBLE_PRECISION
      END SUBROUTINE ppm_map_part_get_sub_d
#endif
