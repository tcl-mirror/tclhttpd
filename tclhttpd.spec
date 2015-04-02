%define contentdir /usr/tclhttpd
Summary: Extensible Web+Application server written in Tcl.
Name: tclhttpd
Version: 3.5.3
Release: 0.fdr.1
Epoch: 0
License: BSD
Group: System Environment/Daemons
URL:            http://tclhttpd.sourceforge.net/
Source0:        http://prdownloads.sourceforge.net/tclhttpd/tclhttpd3.5.3.tar.gz
Patch0:		tclhttpd_fedora.1.patch
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires: tcl tcllib expect
BuildRequires:  tcl-devel 
Prereq: /sbin/chkconfig, /usr/sbin/useradd

%description
TclHttpd is a Web server implemented in pure Tcl. It works out of the box as a
Web server, but is really designed to be a Tcl application server. It supports
HTML+Tcl templates, and is extensible in a variety of ways.

%prep
%setup -q -n %{name}%{version}
%patch -p1

%build

%configure --with-serverroot=%{contentdir}
make %{?_smp_mflags}

%install
make install DESTDIR=$RPM_BUILD_ROOT
install -p -D bin/redhat.init.tclhttpd $RPM_BUILD_ROOT/%{_sysconfdir}/init.d/tclhttpd
mkdir -p $RPM_BUILD_ROOT/var/run/tclhttpd

# Replace the numeric id in this configuration file with a name.  We don't
# know what numeric id it will end up with when it's created during
# the rpm installation.
sed -e 's/Config uid.*/Config uid tclhttpd/' -e 's/Config gid.*/Config gid tclhttpd/' < bin/tclhttpd.rc > $RPM_BUILD_ROOT/%{_prefix}/bin/tclhttpd.rc
# This cgi is precompiled and has some old libc dependencies.  I'm removing
# it until I find out what it's used for.
rm $RPM_BUILD_ROOT/%{contentdir}/htdocs/cgi-bin/env
ln -s ./httpd.tcl $RPM_BUILD_ROOT/%{_prefix}/bin/tclhttpd

%pre
# Add the "tclhttpd" user
%_sbindir/useradd -c "Tclhttpd" -s /sbin/nologin -r -d %{contentdir} tclhttpd 2> /dev/null || :

%post
if [ $1 -eq 1 ]; then
    /sbin/chkconfig --add tclhttpd
# No need to run ldconfig because the shared objects are only
# loaded by Tcl's package system, which doesn't require
# anything in the ld cache.
#    /sbin/ldconfig
fi

%preun
if [ $1 = 0 ]; then
    /sbin/service tclhttpd stop > /dev/null 2>&1
    /sbin/chkconfig --del tclhttpd
    rm -f /var/run/tclhttpd/tclhttpd.pid
fi

%postun
# No need to run ldconfig because the shared objects are only
# loaded by Tcl's package system, which doesn't require
# anything in the ld cache.
#    /sbin/ldconfig
# Clean up a turd that is often left behind

if [ $1 = 0 ]; then                                               # uninstalling
    %_sbindir/userdel tclhttpd
fi
rm -f /tmp/tclhttpd.default

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,tclhttpd,tclhttpd)
%{_libdir}/*.so
%{_libdir}/crypt1.0
%{_libdir}/limit1.0
%{_libdir}/%{name}%{version}
%{_bindir}/*
%{_mandir}/man1/*
%{contentdir}
/var/run/tclhttpd
%{_sysconfdir}/init.d/tclhttpd

%changelog
* Thu Apr 2 2014 <yoda @ etoyoc.com> - 0:3.5.3-0.fdr.1
- Packaged a final stable release of the 3.5 family before releasing 4.0
* Sun Oct 24 2004 <wart at kobold.org> - 0:3.5.1-0.fdr.4
- Change package group in the specfile.  Add tcllib to dependency list.
  Remove tclhttpd user during uninstall.
* Wed Oct 6 2004 <wart at kobold.org> - 0:3.5.1-0.fdr.3
- Fix bug in the /etc/init.d/tclhttpd startup script that was causing
  it to kill a random tclsh process during shutdown, and misreporting
  the status of tclhttpd.
* Tue Sep 21 2004 <wart at kobold.org> - 0:3.5.1-0.fdr.2
- remove hardcoded path in the %build section of the rpm spec file.
* Sun Sep 12 2004 <wart at kobold.org> - 0:3.5.1-0.fdr.1
- Initial rpm with a Fedora-compatible spec file.  Included patch
  for better /etc/init.d script behaviour.
