SHELL=          /bin/sh

LIBS=           ${W3NCO_LIB4} ${W3EMC_LIB4} ${BACIO_LIB4}
FC=             ${COMP}
FFLAGS=         -FR -convert big_endian -cpp 

LDFLAGS=
SRCS=           verfgen.f 
OBJS=           verfgen.o 
CMD=            verf_precip_verfgen

all:            $(CMD)

$(CMD):         $(OBJS)
	        $(FC) $(LDFLAGS) -o $(@) $(OBJS) $(LIBS)
clean:
	-rm -f *.o *.lst $(CMD)
mvexec:
	-mv $(CMD) ../../exec/.

