# auth.tcl
#
# Basic authentication
# This module parses .htaccess files and does the Basic Authentication
# protocol.  There is some generality in here to support multiple
# authentication schemes, but in practice only Basic is used right now.
#
# Each .htaccess file is parsed once and the information is kept in a
# Tcl global array named auth$filename, and upvar aliases this to "info".
# "info" contains the info provided by the .htaccess file ( info(htaccessp,..) )
# The AuthUserFile ( info(user,..) ) and the AuthGroupFile( info(group,..) )
#
# There is also support for ".tclaccess" files in each directory.
# These contain hook code that define password checking procedures
# that apply at that point in the hierarchy.
#
# Brent Welch (c) 1997 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# Piet Vloet (c) 2001
# Brent Welch (c) 2001
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: auth.tcl,v 1.15 2002/08/31 07:30:43 welch Exp $

package provide httpd::auth 2.0
package require base64

# Auth_InitCrypt --
# Attempt to turn on the crypt feature used to store crypted passwords.

proc Auth_InitCrypt {} {
    package require crypt
}
proc Auth_AccessFile {args} {
    Stderr "Auth_AccessFile is obsolete: use Auth_InitCrypt instead"
    Auth_InitCrypt
}

# Auth_Check --
# This looks for access files along the path.
# It returns a "cookie" that is checked by Auth_Verify.
# NOTE: this looks for the lowest (i.e., deepest) access file
# and only returns information about one. Consider changing
# Auth_Check/Auth_Verify to check all files.

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
        if {![file isdirectory $path]} {
            # Don't bother looking if we are in an "artificial"
            # url domain that isn't mapped to files.
            break
        }
	foreach {name type} {.htaccess Basic .tclaccess Tcl} {
	    set file [file join $path $name]
	    if {[file exists $file]} {
		set cookie [list $type $file]
		# Keep looking for cookie files lower in the directory tree
            }
	}
	set path [file join $path $component]
    }

    # Block access to the access control files themselves.
    # We toss in a block against the .tml files as well,
    # although that isn't strictly clean modularity.
    set tail [file tail $path]
    if {$tail == ".tclaccess" ||
          $tail == ".htaccess" ||
          $tail == ".tml"} {
        set cookie [list Deny $path]
        return $cookie
    }

    return $cookie
}

proc Auth_Verify {sock cookie} {
    if {[llength $cookie] == 0} {
	return 1
    }
    set type [lindex $cookie 0]
    set key [lindex $cookie 1]
    if {$type == "Deny"} {
        return 0
    } else {
        return [AuthVerify$type $sock $key]
    }
}

# Auth_VerifyCallback -- 
#
#       Check for a Basic authorization string, and use a callback
#       to verify the password
#
# Arguments:
#       sock            Handle on the client connection
#       realm           Realm for basic authentication.  This appears
#                       in the password prompt from the browser.
#       callback        Tcl command to check the password.  This gets
#                       as arguments the sock, realm, username and password.
#
# Results:
#                       return 1 or 0, 1 for success.

proc Auth_VerifyCallback {sock realm callback} {
    upvar #0 Httpd$sock data

    if {![info exists data(mime,authorization)]} {
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
    if {!$ok} {
	Httpd_RequestAuth $sock Basic $realm
	return 0
    } else {
	set data(auth_type) Basic
	set data(remote_user) $user
	set data(session) $realm,$user
	return 1
    }
}

# AuthVerifyTcl --
#
#       "Tcl" verification uses a .tclaccess file that defines the
#       realm and callback to use to check the password.
#
# Arguments:
#       sock    Handle on the client connection
#       file    Tcl source file that contains set commands for
#               realm and callback
#
# Results:
#       1 for success, 0 for access denied.

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
    if {[info exists auth($realm,$user)]} {
	switch -exact -- $auth($realm,$user) \
	    $pass {
		Stderr "Session: $realm,$user"
		return 1
	    } \
	    PasswordRequired {
		set auth($realm,$user) $pass
		Stderr "Session: $realm,$user"
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

# AuthVerifyBasic - see if the user is granted access.
# First domain based protection is performed. In the case the
# user is not in the domain user based protection is performed.
# The user must be in a group or mentioned as user. The password
# must match the user's entry.  If neither group nor user are
# required for the operation, then the check passes.

proc AuthVerifyBasic {sock file} {
    upvar #0 auth$file info
    upvar #0 Httpd$sock data
    AuthParseHtaccess $sock $file
    set op $data(proto) ;# GET, POST etc.

    if {[info exists info(htaccessp,order,$op)]} {
	if {! [AuthVerifyNet $sock $file $op]} {
	    Httpd_Error $sock 403
	    return 0
	}
    }
    if {![info exists info(htaccessp,require,$op,group)] &&
	    ![info exists info(htaccessp,require,$op,user)]} {
	# No "require group .." or "require user .." in .htaccess file
	return 1
    }
    set ok 0
    if {[info exists data(mime,authorization)]} {
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
	    if {[info exists info(htaccessp,require,$op,group)]} {
		if {![AuthGroupCheck $sock $file \
			$info(htaccessp,require,$op,group) $user]} {
		    set ok  0   ;# Not in a required group
		}
	    }
	    if {! $ok} {
		if {[info exists info(htaccessp,require,$op,user)]} {
		    set ok 1
		    if {![AuthUserCheck $sock $file \
			    $info(htaccessp,require,$op,user) $user]} { 
			set ok  0   ;# Not the required user
		    }
		}
	    }
	}
	if {$ok} {
	    set crypt [AuthGetPass $sock $file $user]
	    set salt [string range $crypt 0 1]
	    set crypt2 [crypt $pass $salt]
	    if {[string compare $crypt $crypt2] != 0} {
		set ok 0        ;# Not the right password
	    }
	}
    }
    if {! $ok} {
	Httpd_RequestAuth $sock Basic $info(htaccessp,name)
    } else {
	set data(auth_type) Basic
	set data(remote_user) $user
	set data(session) $info(htaccessp,name),$user
    }
    return $ok
}

proc AuthUserCheck  {sock file users user } {
    return [expr {[lsearch $users $user] >= 0}]
}

# Parse the AuthGroupFile.                          
# The information is built up in the info array

proc AuthGroupCheck {sock file groups user} {
    upvar #0 auth$file info
    set mtime [file mtime $info(htaccessp,groupfile)]

    # Only parse the group file if it has changed

    if {![info exists info(group,mtime)] || ($mtime > $info(group,mtime))} {
	foreach i [array names info "group*"] {
	    unset info($i)
	}
	if {[catch {open $info(htaccessp,groupfile)} in]} {
	    return 0
	}
	while {[gets $in line] >= 0} {
	    if {[regexp {^([^:]+):[      ]*(.+)} $line x key value]} {
		set info(group,$key) [split $value " ,"]
	    }
	}
	close $in
	set info(group,mtime) $mtime
    }

    foreach index $groups {
	if {[info exist info(group,$index)]} {
	    if {[lsearch $info(group,$index) $user] >= 0} {
		return 1
	    }
	}
    }
    return 0
}

# Parse the AuthUserFile.
# The information is built up in the info array

proc AuthGetPass {sock file user} {
    upvar #0 auth$file info
    set mtime [file mtime $info(htaccessp,userfile)]
    if {![info exists info(user,mtime)] || ($mtime > $info(user,mtime))} {
	foreach i [array names info "user*"] {
	    unset info($i)
	}
	if {[catch {open $info(htaccessp,userfile)} in]} {
	    return *
	}
	while {[gets $in line] >= 0} {
	    if {[regexp {^([^:]+):[      ]*([^:]+)} $line x key value]} {
		set info(user,$key) $value
	    }
	}
	close $in
	set info(user,mtime) $mtime
    }
    if {[info exists info(user,$user)]} {
	return $info(user,$user)
    } else {
	return *
    }
}

# Check the allow/deny lists for this operation

proc AuthVerifyNet {sock file op} {
    upvar #0 auth$file info
    set order [split $info(htaccessp,order,$op) ,]
    set peer [fconfigure $sock -peername]
    set rname [string tolower [lindex $peer 1]]
    set raddr [lindex $peer 0]
    set ok 0
    foreach way $order {
	if {![info exists info(htaccessp,network,$way,$op)]} {
	    continue
	}
	foreach addr $info(htaccessp,network,$way,$op) {
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
    if {![info exists info] || ($mtime > $info(htaccessp,mtime))} {
	# Parse .htaccess file
	foreach i [array names info "htaccessp*"] {
	    unset info($i)
	}
	set info(htaccessp,mtime) $mtime
	set info(htaccessp,userfile) {}
	set info(htaccessp,groupfile) {}
	if {[catch {open $file} in]} {
	    return 1
	}
	set state [list vars]
	foreach line [split [read $in] \n] {
	    if {[regexp ^# $line] || [string length [string trim $line]] == 0} {
		continue
	    }
	    if {[regexp <(.+)> $line x tag]} {
		set line $tag
	    }
	    set words [split $line]
	    set cmd [string tolower [lindex $words 0]]
	    if {[catch {
		eval {Ht-$cmd auth$file} [lrange $words 1 end]
	    } err]} {
		Log $sock Error $err
	    }
	}
	close $in
    }
    return 1
}
proc Ht-authtype {infoName type} {
    upvar #0 $infoName info
    set info(htaccessp,type) $type
}
proc Ht-authname {infoName name} {
    upvar #0 $infoName info
    set info(htaccessp,name) $name
}

proc Ht-authuserfile {infoName file} {
    upvar #0 $infoName info
    set info(htaccessp,userfile) $file
}

proc Ht-authgroupfile {infoName file} {
    upvar #0 $infoName info
    set info(htaccessp,groupfile) $file
}

proc Ht-limit {infoName args} {
    upvar #0 $infoName info
    set info(htaccessp,limit) $args       ;# List of operations, GET, POST, ...
}

proc Ht-/limit {infoName args} {
    upvar #0 $infoName info
    set info(htaccessp,limit) {}
}

proc Ht-require {infoName key list} {
    upvar #0 $infoName info
    if {![info exists info(htaccessp,limit)]} {
	set info(htaccessp,limit) {}
    }
    foreach op $info(htaccessp,limit) {
	if {![info exists info(htaccessp,require,$op,$key)]} {
		set info(htaccessp,require,$op,$key) {}
	    }
	    foreach a $list {
		lappend info(htaccessp,require,$op,$key) $a
	    }
     }
}

proc Ht-order {infoName value} {
    upvar #0 $infoName info
    if {![info exists info(htaccessp,limit)]} {
	set info(htaccessp,limit) {}
    }
    foreach op $info(htaccessp,limit) {
	if {[info exists info(htaccessp,order,$op)]} {
		 unset info(htaccessp,order,$op)
	}
	set info(htaccessp,order,$op) $value
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
    if {![info exists info(htaccessp,limit)]} {
	set info(htaccessp,limit) {}
    }
    if {[string compare [lindex $list 0] "from"] == 0} {
	set list [lrange $list 1 end]
    }
    foreach op $info(htaccessp,limit) {
	if {![info exists info(htaccessp,network,$how,$op)]} {
	    set info(htaccessp,network,$how,$op) {}
	}
	foreach a $list {
	    lappend info(htaccessp,network,$how,$op) [string tolower $a]
	}
    }
}
