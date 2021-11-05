#!/bin/sh
#
#  This makefile is to compile ensembel production generator
#  Author: Binbin Zhou
#  OS: Intel WCOSS
#

FC=     ${COMP}
INC= ${G2_INC4}

BINDIR= ../../exec
LIBS= ${IP_LIB4} ${W3NCO_LIB4} ${W3EMC_LIB4} ${BACIO_LIB4}  ${SP_LIB4} ${G2_LIB4} ${JASPER_LIB} ${PNG_LIB} ${Z_LIB} 
FFLAGS =        -O3 -g -convert big_endian -I $(INC)
CMD=verf_g2g_re-set-time 
CMD4stamp=re-set-time4stamp

all:	$(CMD)

$(CMD):
	$(FC) -o $(@) $(FFLAGS) re-set-time.f $(LIBS)
clean:
	-rm -f *.o $(CMD)
mvexec:
	-mv $(CMD) ../../exec/.
#
