SHELL=		/bin/sh

LIBS=           ${W3NCO_LIB4} ${W3EMC_LIB4} ${BACIO_LIB4}
FC=             ${COMP}
FFLAGS=         -FR -cpp 

LDFLAGS=
SRCS=		diffpcp.f
OBJS=		diffpcp.o
CMD=		verf_precip_diffpcp

all:		$(CMD)

$(CMD):		$(OBJS)
	$(FC) $(LDFLAGS) -o $(@) $(OBJS) $(LIBS)

clean:
	-rm -f *.o *.lst $(CMD)
mvexec:
	-mv $(CMD) ../../exec/.


