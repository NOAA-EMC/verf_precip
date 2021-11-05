SHELL=		/bin/sh
LIBS=           ${W3NCO_LIB4} ${W3EMC_LIB4} ${BACIO_LIB4}
FC=		${COMP}
FFLAGS=         -FR -assume byterecl -cpp 
SRCS=		cmorph2grb.f
OBJS=		cmorph2grb.o 
CMD=		nam_cmorph2grb

all:		$(CMD)

$(CMD):		$(OBJS)
	$(FC) $(LDFLAGS) -o $(@) $(OBJS) $(LIBS)

clean:
	-rm -f *.o *.lst $(CMD)
mvexec:
	-mv $(CMD) ../../exec/.
