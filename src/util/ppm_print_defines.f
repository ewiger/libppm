      !-------------------------------------------------------------------------
      !  Subroutine   :                  ppm_print_defines
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

      SUBROUTINE ppm_print_defines(info)
      !!! Prints what CPP defines were used to compile the PPM library.

      !-------------------------------------------------------------------------
      !  Includes
      !-------------------------------------------------------------------------
      !-------------------------------------------------------------------------
      !  Modules
      !-------------------------------------------------------------------------
      USE ppm_module_data, ONLY: ppm_kind_double, ppm_rank, ppm_debug
      USE ppm_module_substart
      USE ppm_module_substop
      USE ppm_module_write
      USE ppm_module_log
      IMPLICIT NONE
      !-------------------------------------------------------------------------
      !  Arguments     
      !-------------------------------------------------------------------------
      INTEGER                , INTENT(  OUT) :: info
      !!! Returns 0 upon success
      !-------------------------------------------------------------------------
      !  Local variables 
      !-------------------------------------------------------------------------
      ! timer
      REAL(ppm_kind_double)                  :: t0
      !-------------------------------------------------------------------------
      !  Externals 
      !-------------------------------------------------------------------------
      
      !-------------------------------------------------------------------------
      !  Initialise
      !-------------------------------------------------------------------------
      CALL substart('ppm_print_defines',t0,info)

      !-------------------------------------------------------------------------
      !  Check arguments
      !-------------------------------------------------------------------------

      !-------------------------------------------------------------------------
      !  Print the defines and log them
      !-------------------------------------------------------------------------
#ifdef __MPI
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__MPI defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__MPI defined',info)
#endif
#ifdef __Linux
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__Linux defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__Linux defined',info)
#endif
#ifdef __VECTOR
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__VECTOR defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__VECTOR defined',info)
#endif
#ifdef __SXF90
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__SXF90 defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__SXF90 defined',info)
#endif
#ifdef __ETIME
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__ETIME defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__ETIME defined',info)
#endif
#ifdef __METIS
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__METIS defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__METIS defined',info)
#endif
#ifdef __FFTW
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__FFTW defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__FFTW defined',info)
#endif
#ifdef __HYPRE
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__HYPRE defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__HYPRE defined',info)
#endif
#ifdef __XLF
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines','__XLF defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__XLF defined',info)
#endif
#ifdef __MATHKEISAN
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines',    &
     &        '__MATHKEISAN defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__MATHKEISAN defined',info)
#endif
#ifdef __CRAYFISHPACK
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines',    &
     &        '__CRAYFISHPACK defined',info)
      ENDIF
      CALL ppm_log('ppm_print_defines','__CRAYFISHPACK defined',info)
#endif
      IF (ppm_debug .GT. 0) THEN
          CALL ppm_write(ppm_rank,'ppm_print_defines',    &
     &        'See ppm_define.h for descriptions.',info)
      ENDIF

      !-------------------------------------------------------------------------
      !  Return
      !-------------------------------------------------------------------------
 9999 CONTINUE
      CALL substop('ppm_print_defines',t0,info)
      RETURN
      END SUBROUTINE ppm_print_defines
