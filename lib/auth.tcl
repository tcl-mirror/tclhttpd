# auth.tcl
#
# Basic authentication
# This module parses .htaccess files and does the Basic Authentication
# protocol.  There is some generality in here to support multiple
# authentication schemes, but in practice only Basic is used right now.
#
# Each .htaccess file is parsed once and the information is kept in a
# Tcl global array named auth$filename, and upvar aliases this to "info".
#
# Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) auth.tcl 1.7 98/02/24 15:59:42

package provide auth 1.0
package require base64

# This defines the name of the access control file
# and as an important side effect, enables access checking.

proc Auth_AccessFile {{name .htaccess}} {
    global auth
    package require crypt
    set auth(file) $name
}

# Auth_Check is called the first time a URL is hit, and it
# looks for access files.  It returns a "cookie" that is checked
# later each time the URL is fetched.  The cookie is kept in the
# UrlCache, which means you need to flush the
# URL cache when you add protection to a directory.

proc Auth_Check {sock directory pathlist} {
    global auth
    set cookie {}

    # Make sure we do checks in the root
    if {$pathlist==""} {
	 set pathlist ./
    }

    # Look for the .htaccess files that keep Basic Authtication info
    # or .tclaccess files with a general authorization callback
    set path $directory
    foreach component $pathlist {
	foreach {name type} {.htaccess Basic .tclaccess Tcl} {
	    set file [file join $path $name]
	    if [file exists $file] {
		set cookie [list $type $file]
		# Keep looking for cookie files lower in the directory tree
	    }
	}
	set path [file join $path $component]
    }
    return $cookie
}

proc Auth_Verify {sock cookie} {
    if {[llength $cookie] == 0} {
	return 1
    }
    set type [lindex $cookie 0]
    set key [lindex $cookie 1]
    set ok [AuthVerify$type $sock $key]
    return $ok
}

# Auth_VerifyCallback -- 
#
#	Check for a Basic authorization string, and use a callback
#	to verify the password
#
# Arguments:
#	sock		Handle on the client connection
#	realm		Realm for basic authentication.  This appears
#			in the password prompt from the browser.
#	callback	Tcl command to check the password.  This gets
#			as arguments the sock, realm, username and password.
#
# Results:
#			return 1 or 0, 1 for success.

proc Auth_VerifyCallback {sock realm callback} {
    upvar #0 Httpd$sock data

    if ![info exists data(mime,authorization)] {
	set ok 0
    } else {
	set parts [split $data(mime,authorization)]
	set type [lindex $parts 0]
	set code [lindex $parts 1]
	if {[string compare $type Basic] != 0} {
	    set user {}
	    set pass {}
	} else {
	    set parts [split [base64::decode $code] :]
	    set user [lindex $parts 0]
	    set pass [lindex $parts 1]
	}
	set ok [eval $callback {$sock $realm $user $pass}]
    }
    if !$ok {
	Httpd_RequestAuth $sock Basic $realm
	return 0
    } else {
	global env
	set env(REMOTE_USER) $user
	set env(AUTH_TYPE) Basic
	return 1
    }
}

# AuthVerifyTcl --
#
#	"Tcl" verification uses a .tclaccess file that defines the
#	realm and callback to use to check the password.
#
# Arguments:
#	sock	Handle on the client connection
#	file	Tcl source file that contains set commands for
#		realm and callback
#
# Results:
#	1 for success, 0 for access denied.

proc AuthVerifyTcl {sock file} {
    upvar #0 Httpd$sock data


    # The file contains definitions for the "realm" variable
    # and the "callback" script value.

    set realm Realm
    set callback AuthNullCallback
    catch {source $file}

    return [Auth_VerifyCallback $sock $realm $callback]
}

proc AuthNullCallback {sock realm user pass} {
    upvar #0 Httpd$sock data
    global auth
    if [info exists auth($realm,$user)] {
	switch -exact -- $auth($realm,$user) \
	    $pass {
		set data(session) $realm,$user
		Stderr "Session: $data(session)"
		return 1
	    } \
	    PasswordRequired {
		set auth($realm,$user) $pass
		set data(session) $realm,$user
		Stderr "Session: $data(session)"
		return 1
	    } \
	    default {
		return 0
	    }
    } else {
	set auth($realm,$user) PasswordRequired
	return 0
    }
}

# AuthVerifyBasic - see if the user and password are OK.
# The user must be in the group, if required, and the password
# must match the user's entry.  If neither group nor user are
# required for the operation, then the check passes.

proc AuthVerifyBasic {sock file} {
    upvar #0 auth$file info
    upvar #0 Httpd$sock data
    AuthParseHtaccess $sock $file
    set op $data(proto)	;# GET, POST etc.

    if [info exists info(order,$op)] {
	if {! [AuthVerifyNet $sock $file $op]} {
	    Httpd_Error $sock 403
	    return 0
	}
    }
    if {![info exists info(require,$op,group)] &&
	    ![info exists info(require,$op,user)]} {
	return 1
    }
    set ok 0
    if [info exists data(mime,authorization)] {
	set ok 1
	set parts [split $data(mime,authorization)]
	set type [lindex $parts 0]
	set code [lindex $parts 1]
	if {[string compare $type Basic] != 0} {
	    set ok 0
	} else {
	    set parts [split [base64::decode $code] :]
	    set user [lindex $parts 0]
	    set pass [lindex $parts 1]
	    if {[info exists info(require,$op,group)]} {
		if {![AuthGroupCheck $sock $file \
			$info(require,$op,group) $user]} {
		    set ok  0	;# Not in the required group
		}
	    } else {
		if {[string compare $info(require,$op,user) $user] != 0} {
		    set ok  0	;# Not the required user
		}
	    }
	}
	if {$ok} {
	    set crypt [AuthGetPass $sock $file $user]
	    set salt [string range $crypt 0 1]
	    set crypt2 [crypt $pass $salt]
	    if {[string compare $crypt $crypt2] != 0} {
		set ok 0	;# Not the right password
	    }
	}
    }
    if {! $ok} {
	Httpd_RequestAuth $sock Basic $info(name)
    } else {
	global env
	set env(REMOTE_USER) $user
	set env(AUTH_TYPE) Basic
    }
    return $ok
}
proc AuthGroupCheck {sock file group user} {
    upvar #0 auth$file info
    set mtime [file mtime $info(groupfile)]
    if {![info exists info(gfilemtime)] || ($mtime > $info(gfilemtime))} {
	if [catch {open $info(groupfile)} in] {
	    return 0
	}
	while {[gets $in line] >= 0} {
	    if [regexp {^([^:]+):[ 	]*(.+)} $line x key value] {
		set info(group,$key) [split $value " ,"]
	    }
	}
	close $in
    }
    if {![info exist info(group,$group)]} {
	return 0
    } else {
	return [expr {[lsearch $info(group,$group) $user] >= 0}]
    }
}
proc AuthGetPass {sock file user} {
    upvar #0 auth$file info
    set mtime [file mtime $info(userfile)]
    if {![info exists info(ufilemtime)] || ($mtime > $info(ufilemtime))} {
	if [catch {open $info(userfile)} in] {
	    return *
	}
	while {[gets $in line] >= 0} {
	    if [regexp {^([^:]+):[ 	]*([^:]+)} $line x key value] {
		set info(user,$key) $value
	    }
	}
	close $in
    }
    if [info exists info(user,$user)] {
	return $info(user,$user)
    } else {
	return *
    }
}

# Check the allow/deny lists for this operation

proc AuthVerifyNet {sock file op} {
    upvar #0 auth$file info
    set order [split $info(order,$op) ,]
    set peer [fconfigure $sock -peername]
    set rname [string tolower [lindex $peer 1]]
    set raddr [lindex $peer 0]
    set ok 0
    foreach way $order {
	if ![info exists info($way,$op)] {
	    continue
	}
	foreach addr $info($way,$op) {
	    if {[AuthNetMatch $sock $addr $rname $raddr]} {
		if {[string compare $way "allow"] == 0} {
		    set ok 1
		} else {
		    set ok 0
		}
	    }
	}
    }
    if {! $ok} {
	Log $sock AuthVerifyNet "access denied to $rname in [file tail [file dirname $file]]"
    }
    return $ok
}

proc AuthNetMatch {sock addr rname raddr} {
    if {[string compare $addr "all"] == 0} {
	return 1
    }
    if {[string match *$addr $rname] || [string match ${addr}* $raddr]} {
	return 1
    }
    return 0
}

# Parse the htaccess file.  Uhler would probably regsub/subst this,
# but here we just call a Tcl proc to handle each "command" in the file.
# The information is built up in the info array.

proc AuthParseHtaccess {sock file} {
    upvar #0 auth$file info
    set mtime [file mtime $file]
    if {![info exists info] || ($mtime > $info(mtime))} {
	# Parse .htaccess file
	set info(mtime) $mtime
	set info(userfile) {}
	set info(groupfile) {}
	if [catch {open $file} in] {
	    return 1
	}
	set state [list vars]
	foreach line [split [read $in] \n] {
	    if {[regexp ^# $line] || [string length [string trim $line]] == 0} {
		continue
	    }
	    if [regexp <(.+)> $line x tag] {
		set line $tag
	    }
	    set words [split $line]
	    set cmd [string tolower [lindex $words 0]]
	    if [catch {
		eval {Ht-$cmd auth$file} [lrange $words 1 end]
	    } err] {
		Log $sock $err
	    }
	}
	close $in
    }
    return 1
}
proc Ht-authtype {infoName type} {
    upvar #0 $infoName info
    set info(type) $type
}
proc Ht-authname {infoName name} {
    upvar #0 $infoName info
    set info(name) $name
}

proc Ht-authuserfile {infoName file} {
    upvar #0 $infoName info
    set info(userfile) $file
}

proc Ht-authgroupfile {infoName file} {
    upvar #0 $infoName info
    set info(groupfile) $file
}

proc Ht-limit {infoName args} {
    upvar #0 $infoName info
    set info(limit) $args	;# List of operations, GET, POST, ...
}

proc Ht-/limit {infoName args} {
    upvar #0 $infoName info
    set info(limit) {}
}

proc Ht-require {infoName key value} {
    upvar #0 $infoName info
    if ![info exists info(limit)] {
	set info(limit) {}
    }
    foreach op $info(limit) {
	set info(require,$op,$key) $value
    }
}

proc Ht-order {infoName value} {
    upvar #0 $infoName info
    if ![info exists info(limit)] {
	set info(limit) {}
    }
    foreach op $info(limit) {
	set info(order,$op) $value
    }
}

proc Ht-deny {infoName args} {
    HtByNet $infoName deny $args
}
proc Ht-allow {infoName args} {
    HtByNet $infoName allow $args
}
proc HtByNet {infoName how list} {
    upvar #0 $infoName info
    if ![info exists info(limit)] {
	set info(limit) {}
    }
    if {[string compare [lindex $list 0] "from"] == 0} {
	set list [lrange $list 1 end]
    }
    foreach op $info(limit) {
	if ![info exists info($how,$op)] {
	    set info($how,$op) {}
	}
	foreach a $list {
	    lappend info($how,$op) [string tolower $a]
	}
    }
}
