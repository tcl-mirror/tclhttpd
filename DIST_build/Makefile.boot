#
# This Makefile is used to run the configure scripts
# in all the source directories

# These are the packages

TCL_VERSION=8.3.4
TCL = tcl$(TCL_VERSION)
TK = tk$(TCL_VERSION)
THREAD = thread2.4
TCLLIB = tcllib-1.3
HTTPD = tclhttpd3.4

# Edit MODULES if you don't want to build something.

MODULES = $(THREAD) $(TCLLIB) $(HTTPD)
ALL_MODULES = $(TCL) $(MODULES)

all: config make-tcl make-modules install

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

#PLATFORM=solaris-sparc
PLATFORM=linux-ix86
#PLATFORM=win32-ix86
#PLATFORM=irix-mips
#PLATFORM=hpux-parisc

# CONFIG_FLAGS turn on additional configure features.

CONFIG_FLAGS = --enable-gcc --enable-threads
#CONFIG_FLAGS = --enable-symbols 

# The use of prefix and exec_prefix in these rules is done to expand
# the `pwd` that is used in the definition of PREFIX and EXEC_PREFIX
# before the various chdir's done in the rule.

config: build/$(PLATFORM) config-tcl config-modules

config-tcl:
	@echo "$(TCL) configure"
	-pwd=`pwd`; \
	prefix=$(PREFIX) ; \
	exec_prefix=$(EXEC_PREFIX) ; \
        i=$(TCL) ; \
        mkdir $$pwd/build/$(PLATFORM)/$$i ; \
        cd $$pwd/build/$(PLATFORM)/$$i ; \
        path=$$pwd/$$i/$(ARCH)/configure ; \
        echo "Configuring in build/$(PLATFORM)/$$i" ; \
        sh $$path --prefix=$$prefix \
            --exec-prefix=$$exec_prefix \
            $(CONFIG_FLAGS) \
            --with-tcl=$$pwd/build/$(PLATFORM)/$(TCL); \

config-modules:
	@echo "Running configure prefix=$(PREFIX)"
	-pwd=`pwd`; \
	prefix=$(PREFIX) ; \
	exec_prefix=$(EXEC_PREFIX) ; \
	for i in $(MODULES) ; do \
	    echo "" ; \
	    mkdir $$pwd/build/$(PLATFORM)/$$i ; \
	    cd $$pwd/build/$(PLATFORM)/$$i ; \
            path=$$pwd/$$i/configure ; \
	    if test -f $$path ; then \
		echo "Configuring in build/$(PLATFORM)/$$i" ; \
		sh $$path --prefix=$$prefix \
		    --exec-prefix=$$exec_prefix \
		    $(CONFIG_FLAGS) \
		    --with-tcl=$$pwd/build/$(PLATFORM)/$(TCL) \
		    --with-tcl-include=$$pwd/$(TCL)/generic; \
	    else \
		echo "Skipping configure in $$i" ; \
	    fi ; \
	    echo "" ; \
	done;

build:
	mkdir build

build/$(PLATFORM):  build
	mkdir build/$(PLATFORM)

# We have to make and install Tcl first so that the extensions
# can properly find the stubs library.  We also redefine TCLSH_PROG
# to use the installed version so various utilities in tcllib work
# when the make is done there.

make-tcl:
	-pwd=`pwd`; \
	prefix=$(PREFIX) ; \
        echo "Make in $$pwd/build/$(PLATFORM)/$(TCL)" ; \
        cd $$pwd/build/$(PLATFORM)/$(TCL) ; \
        make ; \
        make install

make-modules:
	-pwd=`pwd`; \
	prefix=$(PREFIX) ; \
	for i in $(MODULES) ; do \
	    echo "" ; \
	    if test -f $$pwd/build/$(PLATFORM)/$$i/Makefile ; then \
		echo "Make in $$pwd/build/$(PLATFORM)/$$i" ; \
		cd $$pwd/build/$(PLATFORM)/$$i ; \
		echo "" ; \
		make TCLSH_PROG=$$pwd/install/$(PLATFORM)/bin/tclsh8.3 ; \
	    else \
		echo "Skipping Make for $$i" ; \
	    fi; \
	done;

install: install-force

install-force:
	-mkdir $(PREFIX)
	-mkdir $(EXEC_PREFIX)
	-pwd=`pwd`; \
	prefix=$(PREFIX) ; \
	for i in $(MODULES) ; do \
	    echo "" ; \
	    if test -f $$pwd/build/$(PLATFORM)/$$i/Makefile ; then \
		echo "Make install for $$pwd/build/$(PLATFORM)/$$i" ; \
		echo "" ; \
		cd $$pwd/build/$(PLATFORM)/$$i ; \
		make install; \
	    else \
		if test -f $$pwd/$$i/install.sh ; then \
		    echo "Running install.sh in $$pwd/$$i" ; \
		    echo "" ; \
		    cd $$pwd/$$i ; \
		    ./install.sh $$prefix ; \
		else \
		    echo "Cannot install $$i" ; \
		fi; \
	    fi; \
	done;

# These are examples of how to run Make for different platforms

solaris:
	make PLATFORM=solaris-sparc ARCH=unix config make install

linux:
	make PLATFORM=linux-ix86 ARCH=unix config make install

win:
	make PLATFORM=win32-ix86 ARCH=win config make install
