SHELL=		/bin/sh

FC=             ${COMP}
FFLAGS=         -FR -cpp 

LIBS=           ${W3NCO_LIB4} ${W3EMC_LIB4} ${BACIO_LIB4}

SRCS=		fss.f
OBJS=		fss.o 
CMD=		verf_precip_fss

all:		$(CMD)

$(CMD):		$(OBJS)
	$(FC) $(LDFLAGS) -o $(@) $(OBJS) $(LIBS)
clean:
	-rm -f *.o *.lst $(CMD)
mvexec:
	-mv $(CMD) ../../exec/.

