      !-------------------------------------------------------------------------
      !  Subroutine   :                 ppm_util_qsort
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

#if   __KIND == __SINGLE_PRECISION
      SUBROUTINE ppm_util_qsort_s(inlist,outlist,info)
#elif __KIND == __DOUBLE_PRECISION
      SUBROUTINE ppm_util_qsort_d(inlist,outlist,info)
#elif __KIND == __INTEGER
      SUBROUTINE ppm_util_qsort_i(inlist,outlist,info)
#endif
      !!! From a list of values generates a sort permutation list
      !!!
      !!! [NOTE]
      !!! From Leonard J. Moss of SLAC: +
      !!! Here is a hybrid QuickSort I wrote a number of i years ago.
      !!! It is based on suggestions in Knuth, Volume 3, and
      !!! performs much better than a pure QuickSort on short
      !!! or partially ordered input arrays. +
      !!! SORTRX uses a hybrid QuickSort algorithm, based on
      !!! several suggestions in Knuth, Volume 3, Section 5.2.2.
      !!! In particular, the pivot key [my term] for dividing
      !!! each subsequence is chosen to be the median of the i first,
      !!! last, and middle values of the subsequence; and the
      !!! QuickSort is cut off when a subsequence has 9 or fewer
      !!! elements, and a straight insertion sort of the  entire array
      !!! is done at the end. The result is comparable to a pure
      !!! insertion sort for very short arrays, and very fast for
      !!! very large arrays (of order 12 micro-sec/element on the
      !!! 3081K for arrays of 10K elements).  It is also not
      !!! subject to the poor performance of the pure QuickSort on
      !!! partially ordered data.
      !-------------------------------------------------------------------------
      !  Includes
      !-------------------------------------------------------------------------

      !-------------------------------------------------------------------------
      !  Modules
      !-------------------------------------------------------------------------
      USE ppm_module_data
      USE ppm_module_substart
      USE ppm_module_substop
      USE ppm_module_error
      USE ppm_module_alloc
      IMPLICIT NONE
#if   __KIND == __SINGLE_PRECISION
      INTEGER, PARAMETER :: MK = ppm_kind_single
#elif __KIND == __DOUBLE_PRECISION
      INTEGER, PARAMETER :: MK = ppm_kind_double
#endif
      !-------------------------------------------------------------------------
      !  Arguments     
      !-------------------------------------------------------------------------
#if   __KIND == __INTEGER
      INTEGER,  DIMENSION(:) , POINTER      :: inlist
#else
      REAL(MK), DIMENSION(:) , POINTER      :: inlist
#endif
      !!! List to be sorted
      INTEGER, DIMENSION(:) , POINTER       :: outlist
      !!! Permutation list
      INTEGER               , INTENT(OUT)   :: info
      !!! Return status, 0 on success
      !-------------------------------------------------------------------------
      !  Local variables 
      !-------------------------------------------------------------------------
      REAL(ppm_kind_double)                 :: t0
      INTEGER, DIMENSION(1)                 :: ldl,ldu
      INTEGER                               :: iopt
      !   QuickSort Cutoff
      !   Quit QuickSort-ing when a subsequence contains M or fewer
      !   elements and finish off at end with straight insertion sort.
      !   According to Knuth, V.3, the optimum value of M is around 9.
      INTEGER, PARAMETER                    :: m = 9
      INTEGER                               :: stklength, dn
      INTEGER, DIMENSION(:), POINTER        :: lstk => NULL()
      INTEGER, DIMENSION(:), POINTER        :: rstk => NULL()
      INTEGER                               :: i,j,n,l,r,p,istk,       &
                                            &  indexp,indext,          &
                                            &  inlistu, inlistl
#if __KIND == __INTEGER
      INTEGER                               :: datap
#else
      REAL(MK)                              :: datap
#endif      
      
      !-------------------------------------------------------------------------
      !  Externals 
      !-------------------------------------------------------------------------
      
      !-------------------------------------------------------------------------
      !  Initialization
      !-------------------------------------------------------------------------
      CALL substart('ppm_util_qsort',t0,info)
      
      !-------------------------------------------------------------------------
      !  Check arguments
      !-------------------------------------------------------------------------
      IF (ppm_debug .GT. 0) THEN
        CALL check
        IF (info .NE. 0) GOTO 9999
      ENDIF
      
      inlistl = LBOUND(inlist,1)
      inlistu = UBOUND(inlist,1)
      n = inlistu-inlistl+1
      iopt = ppm_param_alloc_fit
      ldl(1) = inlistl
      ldu(1) = inlistu
      CALL ppm_alloc(outlist,ldl,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_util_qsort',        &
     &        'indices list OUTLIST',__LINE__,info)
          GOTO 9999
      ENDIF
      
      DO i = inlistl,inlistu
         outlist(i) = i
      ENDDO
     
      !-------------------------------------------------------------------------
      ! Compute the log of the list length, it is in fact a bound for the length
      ! of the stack of intervals
      !-------------------------------------------------------------------------
      stklength = 1
      dn = n
      DO
          IF (dn.EQ.0) EXIT
          dn = ISHFT(dn,-1)
          stklength = stklength + 1       
      ENDDO
      stklength = 2*stklength

      !-------------------------------------------------------------------------
      ! Allocate the stack of intervals
      !-------------------------------------------------------------------------
      iopt = ppm_param_alloc_fit
      ldl(1) = 1
      ldu(1) = stklength
      CALL ppm_alloc(lstk,ldl,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_util_qsort',        &
     &        'left indices list LSTK',__LINE__,info)
          GOTO 9999
      ENDIF
      CALL ppm_alloc(rstk,ldl,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_fatal
          CALL ppm_error(ppm_err_alloc,'ppm_util_qsort',        &
     &        'right indices list RSTK',__LINE__,info)
          GOTO 9999
      ENDIF
      
      ! If array is short, skip QuickSort and go directly to
      ! the straight insertion sort.
 
      IF (n.LE.m) GOTO 900

      !-------------------------------------------------------------------------      
      !     QuickSort
      !
      !     The Qn:s correspond roughly to steps in Algorithm Q,
      !     Knuth, V.3, PP.116-117, modified to select the median
      !     of the first, last, and middle elements as the pivot
      !     key (in Knuths notation, K).  Also modified to leave
      !     data in place and produce an outlist array (here:OUTLIST).  To 
      !     simplify comments, let INLIST[I]=INLIST(outlist(I)).
      
      ! Q1 : Initialize 
      istk = 0
      l = inlistl
      r = inlistu
      
  200 CONTINUE
  
      ! Q2: Sort the subsequence INLIST[L]..INLIST[R].
      !
      !     At this point, INLIST[l] <= INLIST[m] <= INLIST[r] for all l < L,
      !     r > R, and L <= m <= R.  (First time through, there is no
      !     DATA for l < L or r > R.)
 
      i=l
      j=r             
      
      ! Q2.5: Select pivot key
      !
      !     Let the pivot, P, be the midpoint of this subsequence,
      !     P=(L+R)/2; then rearrange outlist(L), outlist(P), and outlist(R)
      !     so the corresponding INLIST values are in increasing order.
      !     The pivot key, DATAP, is then DATA[P].
 
      p=(l+r)/2

      indexp=outlist(p)
      datap=inlist(indexp)
 
      IF (inlist(outlist(l)) .GT. datap) THEN
         outlist(p)=outlist(l)
         outlist(l)=indexp
         indexp=outlist(p)
         datap=inlist(indexp)
      ENDIF
 
      IF (datap .GT. inlist(outlist(r))) THEN
         IF (inlist(outlist(l)) .GT. inlist(outlist(r))) THEN
            outlist(p)=outlist(l)
            outlist(l)=outlist(r)
         ELSE
            outlist(p)=outlist(r)
         ENDIF
         outlist(r)=indexp
         indexp=outlist(p)
         datap=inlist(indexp)
      ENDIF
 
      !     Now we swap values between the right and left sides and/or
      !     move DATAP until all smaller values are on the left and all
      !     larger values are on the right.  Neither the left or right
      !     side will be internally ordered yet; however, DATAP will be
      !     in its final position.
 
  300 CONTINUE
      
      ! Q3: Search for datum on left >= DATAP
      !
      !     At this point, DATA[L] <= DATAP.  We can therefore start scanning
      !     up from L, looking for a value >= DATAP (this scan is guaranteed
      !     to terminate since we initially placed DATAP near the middle of
      !     the subsequence).
 
         i=i+1
         IF (inlist(outlist(i)).LT.datap) GOTO 300
 
  400 CONTINUE
 
      ! Q4: Search for datum on right <= DATAP
      !
      !     At this point, DATA[R] >= DATAP.  We can therefore start scanning
      !     down from R, looking for a value <= DATAP (this scan is guaranteed
      !     to terminate since we initially placed DATAP near the middle of
      !     the subsequence).
 
         j=j-1
         IF (inlist(outlist(j)).GT.datap) GOTO 400
         
      ! Q5: Have the two scans collided?
 
      IF (i.LT.j) THEN
 
      ! Q6: No, interchange DATA[I] <--> DATA[J] and continue
         !PRINT *, ' Interchange '
         indext=outlist(i)
         outlist(i)=outlist(j)
         outlist(j)=indext
         GOTO 300
      ELSE
 
      ! Q7: Yes, select next subsequence to sort
      !
      !     At this point, I >= J and DATA[l] <= DATA[I] == DATAP <= DATA[r],
      !     for all L <= l < I and J < r <= R.  If both subsequences are
      !     more than M elements long, push the longer one on the stack and
      !     go back to QuickSort the shorter; if only one is more than M
      !     elements long, go back and QuickSort it; otherwise, pop a
      !     subsequence off the stack and QuickSort it.
         !PRINT *, ' Collision '
         IF (r-j .GE. i-l .AND. i-l .GT. m) THEN
            istk=istk+1
            !Unnecessary check for the stack position
            !IF (istk .GT. stklength) THEN
            !    info = ppm_error_error
            !    CALL ppm_error(ppm_err_wrong_dim,'ppm_util_qsort',        &
            !    &        'ISTK > STKLENGTH',__LINE__,info)
            !    GOTO 9999
            !ENDIF
            lstk(istk)=j+1
            rstk(istk)=r
            r=i-1
         ELSE IF (i-l .GT. r-j .AND. r-j .GT. m) THEN
            istk=istk+1
            ! Unnecessary check for the stack position
            !IF (istk .GT. stklength) THEN
            !    info = ppm_error_error
            !    CALL ppm_error(ppm_err_wrong_dim,'ppm_util_qsort',        &
            !    &        'ISTK > STKLENGTH',__LINE__,info)
            !    GOTO 9999
            !ENDIF
            lstk(istk)=l
            rstk(istk)=i-1
            l=j+1
         ELSE IF (r-j .GT. m) THEN
            l=j+1
         ELSE IF (i-l .GT. m) THEN
            r=i-1
         ELSE
      ! Q8: Pop the stack, or terminate QuickSort if empty
            IF (istk.LT.1) GOTO 900
            l=lstk(istk)
            r=rstk(istk)
            istk=istk-1
         ENDIF
         GOTO 200
      ENDIF
 
  900 CONTINUE
  
      !-------------------------------------------------------------------------
      !
      ! Q9: Straight Insertion sort
 
      DO i=inlistl+1,inlistu
         IF (inlist(outlist(i-1)) .GT. inlist(outlist(i))) THEN
            indexp=outlist(i)
            datap=inlist(indexp)
            p=i-1
  920       CONTINUE
               outlist(p+1) = outlist(p)
               p=p-1
               IF (p.GT.(inlistl-1)) THEN
                  IF (inlist(outlist(p)).GT.datap) GOTO 920
               ENDIF
            outlist(p+1) = indexp
         ENDIF
       ENDDO
 
      !-------------------------------------------------------------------------
      ! Deallocate the stack of intervals
      !-------------------------------------------------------------------------
      iopt = ppm_param_dealloc
      CALL ppm_alloc(lstk,ldl,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_error
          CALL ppm_error(ppm_err_dealloc,'ppm_util_qsort',        &
     &        'left indices list LSTK',__LINE__,info)
      ENDIF
      CALL ppm_alloc(rstk,ldl,ldu,iopt,info)
      IF (info .NE. 0) THEN
          info = ppm_error_error
          CALL ppm_error(ppm_err_dealloc,'ppm_util_qsort',        &
     &        'right indices list RSTK',__LINE__,info)
      ENDIF
      
      !===================================================================
      !
      !     All done


      !-------------------------------------------------------------------------
      !  Return
      !-------------------------------------------------------------------------
 9999 CONTINUE
      CALL substop('ppm_util_qsort',t0,info)
      RETURN
      CONTAINS
      SUBROUTINE check
          IF (.NOT.ASSOCIATED(inlist)) THEN
              info = ppm_error_error
              CALL ppm_error(ppm_err_argument,'ppm_util_qsort',  &
     &            'inlist must be associated/allocated',__LINE__,info)
              GOTO 8888
          ENDIF
 8888     CONTINUE
      END SUBROUTINE check
#if   __KIND == __SINGLE_PRECISION
      END SUBROUTINE ppm_util_qsort_s
#elif __KIND == __DOUBLE_PRECISION
      END SUBROUTINE ppm_util_qsort_d
#elif __KIND == __INTEGER
      END SUBROUTINE ppm_util_qsort_i
#endif    
