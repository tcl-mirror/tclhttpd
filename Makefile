# Generated automatically from Makefile.in by configure.
# Makefile.in --
#
#	This file is a Makefile for the tclhttpd web server
#
# Copyright (c) 1999-2000 Scriptics Corporation.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: Makefile,v 1.13 2000/02/11 21:38:08 awb Exp $

# TEMPORARY:  Values for the dist target.

#========================================================================
# Edit the following few lines when writing a new extension
#========================================================================

#========================================================================
# Change the name of the variable "exampleA_LIB_FILE" to match the one
# used in the configure script.  This is the parameterized name of the
# library that we are building.
#========================================================================

lib_BINARIES=$(crypt_LIB_FILE)
BINARIES=$(lib_BINARIES)

#========================================================================
# Enumerate the names of the source files included in this package.
# This will be used when a dist target is added to the Makefile.
#========================================================================

crypt_SOURCES = src/crypt. src/cryptLib.c
SOURCES = $(crypt_SOURCES)

#========================================================================
# Enumerate the names of the object files included in this package.
# These objects are created and linked into the final library.  In
# most cases these object files will correspond to the source files
# above.
#
#========================================================================

crypt_OBJECTS =  crypt.$(OBJEXT) cryptLib.${OBJEXT}
OBJECTS = $(crypt_OBJECTS)

#========================================================================
# The substitution of "exampleA_LIB_FILE" into the variable name below
# allows us to refer to the objects for the library without knowing the name
# of the library in advance.  It also lets us use the "$@" variable in
# the rule for building the library, so we can refer to both the list of 
# objects and the library itself in a platform-independent manner.
#========================================================================

crypt_LIB_FILE = crypt23.dll
$(crypt_LIB_FILE)_OBJECTS = $(crypt_OBJECTS)

#========================================================================
# This is a list of header files to be installed
#========================================================================

GENERIC_HDRS= 

#========================================================================
# Add additional lines to handle any additional AC_SUBST cases that
# have been added to the configure script.
#========================================================================

# SAMPLE_NEW_VAR=@SAMPLE_NEW_VAR@

DISTDIR=/tmp/
DEST=${DISTDIR}/tclhttpd${VERSION}

HTDOCS_FILES = \
	error.html \
	.tml \
	access/auth/.htaccess \
	access/auth/hello.txt \
	access/.htaccess \
	access/README.txt \
	access/bydir/.htaccess \
	access/bydir/README.txt \
	access/bydir/user.cgi \
	access/bytcl/.tclaccess \
	access/noawe/.htaccess \
	access/session/.tclaccess \
	access/session/page.auth \
	hacks.html \
	include.shtml \
	index.html \
	license.terms \
	notfound.html \
	register.html \
	book/TCLHTTPD-1.gif \
	book/TCLHTTPD-2.gif \
	book/TCLHTTPD.css \
	book/TCLHTTPD.html \
	cgi-bin/big.cgi \
	cgi-bin/cgilib.tcl \
	cgi-bin/cwd.cgi \
	cgi-bin/debugee.cgi \
	cgi-bin/env \
	cgi-bin/env.cgi \
	cgi-bin/err0.cgi \
	cgi-bin/err1.cgi \
	cgi-bin/err2.cgi \
	cgi-bin/flip.cgi \
	cgi-bin/junk \
	cgi-bin/junk.exe \
	cgi-bin/prodebug.tcl \
	cgi-bin/redirect.cgi \
	cgi-bin/sleep.cgi \
	cgi-bin/tclIndex \
	cgi-bin/test.cgi \
	cgi-bin/user.cgi \
	forms/file.html \
	forms/form1.html \
	forms/index.html \
	forms/posttest.html \
	guestbook/guestbook.cgi \
	guestbook/newguest.cgi \
	guestbook/newguest.html \
	images/Blue.gif \
	images/Red.gif \
	images/ScripticsLogo1.gif \
	images/TclPro200.gif \
	images/lake.gif \
	images/lake.map \
	images/logo125.gif \
	images/ppt1.gif \
	images/ppt2.gif \
	images/ppt3.gif \
	images/ppt4.gif \
	images/ppt5.gif \
	images/pwrdLogo100.gif \
	images/pwrdLogo150.gif \
	images/pwrdLogo175.gif \
	images/pwrdLogo200.gif \
	images/pwrdLogo75.gif \
	images/setup.gif \
	images/tcl89.gif \
	include/footer.html \
	java/Auth.class \
	java/Getpass.class \
	java/Helper.class \
	java/MD5.class \
	java/README \
	java/ServerDemo.class \
	java/ServerDemo.html \
	java/auth.js \
	java/test.html \
	libtml/faq.tcl \
	libtml/form.tcl \
	libtml/htmlutils.tcl \
	libtml/pkgIndex.tcl \
	libtml/ss_survey.tcl \
	libtml/sunscript.tcl \
	manual/htdig.html \
	manual/reference.html \
	manual/stdin.html \
	map/bush.html \
	map/index.html \
	map/mapdefault.html \
	map/surfer.html \
	snmp/browser/end.snmp \
	snmp/browser/README \
	snmp/browser/browser.snmp \
	snmp/browser/browser2.snmp \
	snmp/browser/control.snmp \
	snmp/browser/start.html \
	snmp/browser/table.snmp \
	snmp/browser/title.html \
	snmp/browser/title.snmp \
	snmp/browser/walk.snmp \
	snmp/browser/walker.snmp \
	snmp/allport.snmp \
	snmp/discover.snmp \
	snmp/host.snmp \
	snmp/index.html \
	snmp/outdiscov.snmp \
	snmp/portdetail.snmp \
	snmp/repeat.snmp \
	snmp/system.snmp \
	snmp/telnet.snmp \
	snmp/telnet_pass.snmp \
	snmp/test_mibTable/index.html \
	snmp/test_mibTable/README \
	snmp/test_mibTable/table1.snmp \
	snmp/test_mibTable/table2.snmp \
	snmp/test_mibTable/table3.snmp \
	snmp/test_mibTable/table4.snmp \
	snmp/test_mibTable/test2.snmp \
	stats/doc.tml \
	stats/.tml \
	stats/index.tml \
	stats/notfound.tml \
	templates/form.tml \
	templates/.tml \
	templates/index.tml \
	templates/simple.subst

HTDOCS_DIRS = \
	access \
	access/auth \
	access/bydir \
	access/bytcl \
	access/noawe \
	access/session \
	book \
	cgi-bin \
	forms \
	guestbook \
	images \
	include \
	java \
	libtml \
	manual \
	map \
	snmp \
	snmp/browser \
	snmp/test_mibTable \
	stats \
	templates

#========================================================================
# Nothing of the variables below this line need to be changed.  Please
# check the TARGETS section below to make sure the make targets are
# correct.
#========================================================================

SHELL = /bin/sh

srcdir = .
top_srcdir = .
prefix = /usr/local
exec_prefix = //d/usr/local

bindir = ${exec_prefix}/bin
sbindir = ${exec_prefix}/sbin
libexecdir = ${exec_prefix}/libexec
datadir = ${prefix}/share
sysconfdir = ${prefix}/etc
sharedstatedir = ${prefix}/com
localstatedir = ${prefix}/var
libdir = ${exec_prefix}/lib
infodir = ${prefix}/info
mandir = ${prefix}/man
includedir = ${prefix}/include
oldincludedir = /usr/include

DESTDIR =

pkgdatadir = $(datadir)/tclhttpd2.3.6
pkglibdir = $(libdir)/tclhttpd2.3.6
altpkg1libdir = $(libdir)/crypt2.3.6
pkgincludedir = $(includedir)/tclhttpd2.3.6

top_builddir = .

INSTALL = //d/cygnus/CYGWIN~1/H-I586~1/bin/install -c
INSTALL_PROGRAM = ${INSTALL}
INSTALL_DATA = ${INSTALL} -m 644
INSTALL_SCRIPT = ${INSTALL_PROGRAM}
INSTALL_STRIP_FLAG =
transform = s,x,x,

NORMAL_INSTALL = :
PRE_INSTALL = :
POST_INSTALL = :
NORMAL_UNINSTALL = :
PRE_UNINSTALL = :
POST_UNINSTALL = :

PACKAGE = tclhttpd
VERSION = 2.3.6
CC = cl
CFLAGS_DEBUG = -nologo -Z7 -Od -WX -MDd
CFLAGS_DEFAULT = -nologo -Oti -Gs -GD -MD
CFLAGS_OPTIMIZE = -nologo -Oti -Gs -GD -MD
CLEANFILES = *.lib *.dll *.exp *.ilk *.pdb vc50.pch
EXEEXT = .exe
LDFLAGS_DEBUG = @LDFLAGS_DEBUG@
LDFLAGS_DEFAULT = -release
LDFLAGS_OPTIMIZE = @LDFLAGS_OPTIMIZE@
MAKE_LIB = ${SHLIB_LD} ${SHLIB_LDFLAGS} ${SHLIB_LD_LIBS} $(LDFLAGS) -out:$@ $($@_OBJECTS) 
MAKE_SHARED_LIB = ${SHLIB_LD} ${SHLIB_LDFLAGS} ${SHLIB_LD_LIBS} $(LDFLAGS) -out:$@ $($@_OBJECTS) 
MAKE_STATIC_LIB = ${STLIB_LD} -out:$@ $($@_OBJECTS) 
OBJEXT = obj
RANLIB = :
SHLIB_CFLAGS = 
SHLIB_LD = link -dll -nologo
SHLIB_LDFLAGS = 
SHLIB_LD_LIBS = "d:\usr\local\lib\tclstub83d.lib" user32.lib advapi32.lib
STLIB_LD = lib -nologo
TCL_BIN_DIR = /usr/local/lib
TCL_DEFS =  
TCL_EXTRA_CFLAGS = -YX
TCL_LD_FLAGS = -debug:full -debugtype:cv
TCL_LIBS = @DL_LIBS@ user32.lib advapi32.lib @MATH_LIBS@
TCL_SHLIB_LD_LIBS = user32.lib advapi32.lib
TCL_SRC_DIR = //Z/c2projects/tcl8.3/win
TCL_DBGX = 
TCL_STUB_LIB_FILE = tclstub83d.lib
TCL_STUB_LIB_SPEC = @TCL_STUB_LIB_SPEC@
TCL_TOOL_DIR_NATIVE = @TCL_TOOL_DIR_NATIVE@
TCL_TOP_DIR_NATIVE = @TCL_TOP_DIR_NATIVE@
TCL_UNIX_DIR_NATIVE = @TCL_UNIX_DIR_NATIVE@
TCL_WIN_DIR_NATIVE = @TCL_WIN_DIR_NATIVE@
INCLUDE_DIR_NATIVE = @INCLUDE_DIR_NATIVE@
TCL_BMAP_DIR_NATIVE = @TCL_BMAP_DIR_NATIVE@
TCL_PLATFORM_DIR_NATIVE = @TCL_PLATFORM_DIR_NATIVE@
TCL_GENERIC_DIR_NATIVE = @TCL_GENERIC_DIR_NATIVE@
TCLSH_PROG = //d/usr/local/bin/tclsh83d.exe
SHARED_BUILD = 1

AUTOCONF = autoconf

LDFLAGS = $(LDFLAGS_DEFAULT)

INCLUDES = -I"d:\usr\local\include"

EXTRA_CFLAGS = $(TCL_DEFS) $(PROTO_FLAGS) $(SECURITY_FLAGS) $(MEM_DEBUG_FLAGS) $(KEYSYM_FLAGS) $(NO_DEPRECATED_FLAGS)

DEFS =  -DVERSION=\"2.3.6\" -DBUILD_tclhttpd=1 -DUSE_TCL_STUBS=1  $(EXTRA_CFLAGS)

ACLOCAL_M4 = $(top_srcdir)/aclocal.m4
CONFIGDIR = $(top_srcdir)
mkinstalldirs = $(SHELL) $(CONFIGDIR)/mkinstalldirs
CONFIG_CLEAN_FILES = mkIndex.tcl

CPPFLAGS = 
LIBS = 
AR = ar
CFLAGS = ${CFLAGS_DEFAULT} ${CFLAGS_WARNING} ${SHLIB_CFLAGS}
COMPILE = $(CC) $(DEFS) $(INCLUDES) $(AM_CPPFLAGS) $(CPPFLAGS) $(AM_CFLAGS) $(CFLAGS)
CCLD = $(CC)
LINK = $(CCLD) $(AM_CFLAGS) $(CFLAGS) $(LDFLAGS) -o $@

#========================================================================
# Start of user-definable TARGETS section
#========================================================================

#========================================================================
# TEA TARGETS.  Please note that the "libraries:" target refers to platform
# independent files, and the "binaries:" target inclues executable programs and
# platform-dependent libraries.  Modify these targets so that they install
# the various pieces of your package.  The make and install rules
# for the BINARIES that you specified above have already been done.
#========================================================================

all: binaries libraries doc

#========================================================================
# The binaries target builds executable programs, Windows .dll's, unix
# shared/static libraries, and any other platform-dependent files.
# The list of targets to build for "binaries:" is specified at the top
# of the Makefile, in the "BINARIES" variable.
#========================================================================

binaries: $(BINARIES)

libraries:

doc:

install: all install-binaries install-libraries install-doc

install-binaries: binaries install-lib-binaries
	$(TCLSH_PROG) mkIndex.tcl $(crypt_LIB_FILE)
	if test "x$(SHARED_BUILD)" = "x1"; then \
	    $(TCLSH_PROG) mkIndex.tcl $(crypt_LIB_FILE); \
	fi

test:

depend:

#========================================================================
# Enumerate the names of the object files included in this package.
# These objects are created and linked into the final library.  In
# most cases these object files will correspond to the source files
# above.
#
# $(exampleA_LIB_FILE) should be listed as part of the BINARIES variable
# at the top of the Makefile.  That will ensure that this target is built
# when you run "make binaries".
#
# You shouldn't need to modify this target, except to change the package
# name from "exampleA" to your package's name.
#========================================================================

$(crypt_LIB_FILE): $(crypt_OBJECTS)
	-rm -f $(crypt_LIB_FILE)
	${SHLIB_LD} ${SHLIB_LDFLAGS} ${SHLIB_LD_LIBS} $(LDFLAGS) -out:$@ $($@_OBJECTS) 
	$(RANLIB) $(crypt_LIB_FILE)

#========================================================================
# We need to enumerate the list of .c to .o lines here.
# Unfortunately, there does not seem to be any other way to do this
# in a Makefile-independent way.  We can't use VPATH because it picks up
# object files that may be located in the source directory.
#
# In the following lines, $(srcdir) refers to the toplevel directory
# containing your extension.  If your sources are in a subdirectory,
# you will have to modify the paths to reflect this:
#
# exampleA.$(OBJEXT): $(srcdir)/src/win/exampleA.c
# 	$(COMPILE) -c `cygpath -w $(srcdir)/src/win/exampleA.c` -o $@
#========================================================================

crypt.$(OBJEXT): $(srcdir)/src/crypt.c
	$(COMPILE) -c `cygpath -w $(srcdir)/src/crypt.c` -o $@

cryptLib.$(OBJEXT): $(srcdir)/src/cryptLib.c
	$(COMPILE) -c `cygpath -w $(srcdir)/src/cryptLib.c` -o $@


install-binaries:

install-libraries: installdirs install-htdocs
	@echo "Installing script programs in $(prefix)/bin"
	@for i in $(srcdir)/bin/*.tcl ; do \
	    $(INSTALL_SCRIPT) $$i $(prefix)/bin ; \
	done;
	@for i in $(srcdir)/bin/*.rc ; do \
	    $(INSTALL_SCRIPT) $$i $(prefix)/bin ; \
	done;
	@echo "Installing script files in $(pkglibdir)"
	@for i in $(srcdir)/lib/*.tcl ; do \
	    $(INSTALL_SCRIPT) $$i $(pkglibdir) ; \
	done;
	$(INSTALL_SCRIPT) $(srcdir)/lib/mime.types $(pkglibdir)

install-htdocs:
	@echo "Creating skeleton htdocs tree in $(htdocsdir)"
	@for i in $(HTDOCS_DIRS) ; do \
	    $(mkinstalldirs) $(htdocsdir)/$$i ; \
	done ;
	@echo "Populating htdocs tree..."
	@for i in $(HTDOCS_FILES) ; do \
	    $(INSTALL_SCRIPT) $(srcdir)/htdocs/$$i $(htdocsdir)/$$i ; \
	done;

install-doc:

installdirs:
	$(mkinstalldirs) $(pkglibdir) $(altpkg1libdir) $(prefix)/bin $(htdocsdir)

clean:  
	-test -z "$(BINARIES)" || rm -f $(BINARIES)
	-rm -f *.o core *.core
	-rm -f *.$(OBJEXT)
	-test -z "$(CLEANFILES)" || rm -f $(CLEANFILES)

distclean: clean
	-rm -f *.tab.c
	-rm -f Makefile $(CONFIG_CLEAN_FILES)
	-rm -f config.cache config.log stamp-h stamp-h[0-9]*
	-rm -f config.status

#========================================================================
# Install binary object libraries.  On Windows this includes both .dll and
# .lib files.  Because the .lib files are not explicitly listed anywhere,
# we need to deduce their existence from the .dll file of the same name.
# Additionally, the .dll files go into the bin directory, but the .lib
# files go into the lib directory.  On Unix platforms, all library files
# go into the lib directory.  In addition, this will generate the pkgIndex.tcl
# file in the install location (assuming it can find a usable tclsh8.2 shell)
#
# You should not have to modify this target.
#========================================================================

install-lib-binaries: installdirs
	@list='$(lib_BINARIES)'; for p in $$list; do \
	  if test -f $$p; then \
	    ext=`echo $$p|sed -e "s/.*\.//"`; \
	    if test "x$$ext" = "xdll"; then \
	        echo " $(INSTALL_DATA) $$p $(DESTDIR)$(bindir)/$$p"; \
	        $(INSTALL_DATA) $$p $(DESTDIR)$(bindir)/$$p; \
		lib=`basename $$p|sed -e 's/.[^.]*$$//'`.lib; \
		if test -f $$lib; then \
		    echo " $(INSTALL_DATA) $$lib $(DESTDIR)$(libdir)/$$lib"; \
	            $(INSTALL_DATA) $$lib $(DESTDIR)$(libdir)/$$lib; \
		fi; \
	    else \
		echo " $(INSTALL_DATA) $$p $(DESTDIR)$(libdir)/$$p"; \
	        $(INSTALL_DATA) $$p $(DESTDIR)$(libdir)/$$p; \
	    fi; \
	  else :; fi; \
	done
	@list='$(lib_BINARIES)'; for p in $$list; do \
	  if test -f $$p; then \
	    echo " $(RANLIB) $(DESTDIR)$(libdir)/$$p"; \
	    $(RANLIB) $(DESTDIR)$(libdir)/$$p; \
	  else :; fi; \
	done

Makefile: $(srcdir)/Makefile.in  $(top_builddir)/config.status
	cd $(top_builddir) \
	  && CONFIG_FILES=$@ CONFIG_HEADERS= $(SHELL) ./config.status

# dist target

dist:
	rm -rf $(DEST)
	$(TCLSH_PROG) $(srcdir)/bin/CopyDist `pwd` $(DEST)
	(cd $(DISTDIR); tar cf - ./tclhttpd$(VERSION) | gzip > tclhttpd$(VERSION).tar.gz)
	(cd $(DISTDIR) ; zip -9 -r -o  tclhttpd$(WIN_VERSION).zip  tclhttpd$(VERSION))
.PHONY: all binaries clean depend distclean doc install installdirs \
libraries test

# Tell versions [3.59,3.63) of GNU make to not export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
