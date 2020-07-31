SHELL=          /bin/sh
LIBS=           

FC=             ifort
FFLAGS=         -FR -cpp 

LDFLAGS=
SRCS=           brkout_ndas.f
OBJS=           brkout_ndas.o
CMD=            verf_precip_brkout_ndas

all:            $(CMD)

$(CMD):         $(OBJS)
	        $(FC) $(LDFLAGS) -o $(@) $(OBJS) $(LIBS)
clean:
	-rm -f *.o *.lst $(CMD)
mvexec:
	-mv $(CMD) ../../exec/.
