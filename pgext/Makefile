MODULES = rparser
# OBJS = rparser.o $(WIN32RES)

EXTENSION = rparser
DATA = rparser--1.0.sql
PGFILEDESC = "rparser - Text search parser for Runestone"

REGRESS = rparser
# We need a UTF8 database
ENCODING = UTF8
NO_LOCALE = 1
PG_CFLAGS = -I/usr/local/include -L/usr/local/lib -lunistring
 # -Wl,-rpath /usr/local/lib
SHLIB_LINK  += -lunistring
# LD_LIBRARY_PATH=/usr/local/lib
# PG_LDFLAGS = "-rpath /usr/local/lib"

#ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
#else
#subdir = contrib/pg_runestone_parser
#top_builddir = ../..
#include $(top_builddir)/src/Makefile.global
#include $(top_srcdir)/contrib/contrib-global.mk
#endif
