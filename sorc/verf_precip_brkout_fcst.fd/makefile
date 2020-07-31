SHELL=          /bin/sh

FC=             ifort
FFLAGS=         -FR -cpp 

LDFLAGS=        
SRCS=           brkout_fcst.f
OBJS=           brkout_fcst.o
CMD=            verf_precip_brkout_fcst

all:            $(CMD)

$(CMD):         $(OBJS)
	        $(FC) $(LDFLAGS) -o $(@) $(OBJS) $(LIBS)
clean:
	-rm -f *.o *.lst $(CMD)
mvexec:
	-mv $(CMD) ../../exec/.
