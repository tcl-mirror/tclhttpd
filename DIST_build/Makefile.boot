#
# This Makefile is used to run the configure scripts
# in all the source directories

# These are the packages

TCL_VERSION=8.3.1
TCL = tcl$(TCL_VERSION)
TK = tk$(TCL_VERSION)
THREAD = thread2.0
TCLLIB = tcllib0.5

# Edit MODULES if you don't want to build something.

MODULES = $(TCL) $(TK) $(THREAD) $(TCLLIB)

all: config 

# PREFIX - this defines the root of the installation directory
# EXEC_PREFIX - typically a sub-directory of PREFIX used to
#	keep platform-specific binary files.

PREFIX=`pwd`/install
EXEC_PREFIX=$(PREFIX)/$(PLATFORM)

# Change ARCH so you can find the Tcl and Tk configure files.

ARCH=unix
#ARCH=win
#ARCH=mac

# Change PLATFORM so your builds and binaries are in a platform-specific dir.

PLATFORM=solaris-sparc
#PLATFORM=linux-ix86
#PLATFORM=win32-ix86
#PLATFORM=irix-mips
#PLATFORM=hpux-parisc

# CONFIG_FLAGS turn on additional configure features.

CONFIG_FLAGS = --enable-gcc 
#CONFIG_FLAGS = --enable-threads 
#CONFIG_FLAGS = --enable-symbols 

config: build
	@echo "Running configure""
	pwd=`pwd`; \
	for i in $(MODULES) ; do \
	    mkdir build/$(PLATFORM)/$$i ; \
	    cd build/$(PLATFORM)/$$i ; \
	    if test -f $$pwd/$$i/$(ARCH)/configure ; then \
		path=$$pwd/$$i/$(ARCH)/configure ; \
	    else \
		path=$$pwd/$$i/configure ; \
	    fi; \
	    sh $$path --prefix=$(PREFIX) \
		--exec-prefix=$(EXEC_PREFIX) \
		$(CONFIG_FLAGS) \
		--with-tcl=$$pwd/build/$(PLATFORM)/$(TCL)
	done;

build: build/$(PLATFORM)
	mkdir build

build/$(PLATFORM): 
	mkdir build/$(PLATFORM)

