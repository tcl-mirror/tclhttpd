# digest.tcl
#
# Provides Digest Authentication, per http://www.ietf.org/rfc/rfc2617.txt
# Works in conjunction with auth.tcl, requires tcllib.
# Digest authentication is selectable in .htaccess.
# No provision for dual Basic/Digest authentication.
#
# Supports only algorithm=MD5 and qop=auth
# (which is more than most browsers support :)
#
# Copyright 2004 Colin McCormack.  colin@chinix.com
# Licensed on terms identical to tclhttpd's license.

package require base64

package provide httpd::digest 1.0
package require httpd::md5hex
package require httpd::auth

# generate private key
if {[catch {package require Random}]} {
    # use the built in tcl random
    proc DigestRand {} {
	return [expr {rand() * 65536}]
    }
} else {
    # use http://mini.net/tcl/random
    # cvs -d:pserver:anonymous@cvs.tclsoap.sourceforge.net:/cvsroot/tclsoap co Random
    # generate a random seed
    if {[catch {
	# try for hardware support
	set r [open /dev/random]
	binary scan [read $r 4] I seed
	close $r
    }]} {
	set seed [clock clicks]
    }
    ::isaac::isaac seed $seed	;# seed random

    # get an integer secret
    proc DigestRand {} {
	return [::isaac::isaac integer]
    }
}
set DigestSecret [DigestRand]

proc Digest_Passwd {username realm passwd} {
    return [string tolower [md5hex "$username:$realm:$passwd"]]
}

# calculate a digest key for a given session
proc DigestA1 {sock} {
    upvar #0 Httpd$sock data
    upvar #0 Digest$data(digest,nonce) digest

    # create a digest for this socket
    set userstuff "$data(digest,username):$data(digest,realm):$digest(passwd)"
    #Stderr "DigestA1: $userstuff"
    switch -- [string tolower $data(digest,algorithm)] {
	md5 {
	    set digest(A1) [md5hex $userstuff]
	}
	md5-sess {
	    set digest(A1) [md5hex "[string tolower [md5hex $userstuff]]:$data(digest,nonce):$data(digest,cnonce)"]
	}
	default {
	    error "unknown algorithm: $data(digest,algorithm)"
	}
    }
    set digest(A1) [string tolower $digest(A1)]
    return $digest(A1)
}

# per operation hash
proc DigestA2 {sock} {
    upvar #0 Httpd$sock data
    set uri $data(digest,uri)
    regexp {[^?]+} $uri uri
    if {[info exists data(proto)]} {
	#Stderr "A2: op:$data(proto) uri:$data(digest,uri)"
	set result [string tolower [md5hex "[string toupper $data(proto)]:$data(digest,uri)"]]
	# nb: we don't offer auth-int
    } else {
	#Stderr "A2: uri:$data(digest,uri)"
	set result [string tolower [md5hex "GET:$data(digest,uri)"]]
    }
    return [string tolower $result]
}

# generate a nonce
proc DigestNonce {} {
    #return "dcd98b7102dd2f0e8b11d0f600bfb0c093"	;# test

    global DigestSecret
    set time [clock clicks]
    return [string tolower [md5hex ${time}:${DigestSecret}]]
}

# calculate the digest value for a given operation and session
proc DigestDigest {sock} {
    upvar #0 Httpd$sock data
    upvar #0 Digest$data(digest,nonce) digest
    if {![info exists digest(A1)]} {
	set digest(A1) [DigestA1 $sock]
    }
    set digest(A2) [DigestA2 $sock]

    #Stderr "DigestDigest A1:$digest(A1) A2:$digest(A2) nc:[format %08x $data(digest,nc)] cnonce:$data(digest,cnonce) qop:$data(digest,qop)"

    if {[info exists data(digest,qop)]} {
	set result [md5hex "$digest(A1):$data(digest,nonce):[format %08x $data(digest,nc)]:$data(digest,cnonce):$data(digest,qop):$digest(A2)"]
    } else {
	set result [md5hex "$digest(A1):$data(digest,nonce):$digest(A2)"]
    }
    return [string tolower $result]
}

# handle the client's Digest
proc Digest_Request {sock realm file} {
    upvar #0 Httpd$sock data
    upvar #0 Digest$data(digest,nonce) digest
    set digest(last) [clock clicks]	;# remember the last use

    if {![info exists digest(A1)]} {
	set A1 [AuthGetPass $sock $file $data(digest,username)@$data(digest,realm)]
	if {$A1 != "*"} {
	    set digest(A1) $A1
	} else {
	    # no digest password on record - use plaintext password
	    if {![info exists digest(passwd)]} {
		set digest(passwd) [AuthGetPass $sock $file $data(digest,username)]
	    }
	    set digest(A1) [DigestA1 $sock]
	    #Stderr "Plaintext password $digest(passwd)"
	}
	#Stderr "A1 Calc: $digest(A1)"
    }

    # check that realms match
    if {$realm != $data(digest,realm)} {
	#Stderr "realm"
	return 0
    }

    #Stderr "Digest_Request: [array get digest] - [array get data digest,*]"

    if {[info exists digest(opaque)]} {
	if {$digest(opaque) != $data(digest,opaque)} {
	    #Stderr "Digest Opaque $digest(opaque) ne $data(digest,opaque)"
	    return 0
	}
    }

    # check the nonce count
    set data(digest,nc) [scan $data(digest,nc) %08x]
    if {[info exists digest(nc)]} {
	if { $data(digest,nc) <= $digest(nc)} {
	    set digest(stale) 1
	    #Stderr "Digest Stale $digest(nc) ne $data(digest,nc)"
	    #return 0	;# Mozilla doesn't implement nc
	}
	#Stderr "Digest nc $digest(nc) - $data(digest,nc)"
    } else {
	#Stderr "Digest New Nonce $data(digest,nc)"
	return 0	;# this is new to us
    }
    set digest(nc) $data(digest,nc)

    # check the password
    set calc_digest [DigestDigest $sock]
    if {$calc_digest != $data(digest,response)} {
	#Stderr "Digest Response: $calc_digest ne $data(digest,response)"
	return 0
    }

    # successful authentication
    # construct authentication args
    set a_args "qop=auth"
    if {[info exists data(digest,cnonce)]} {
	append a_args ", cnonce=\"$data(digest,cnonce)\""
	append a_args ", rspauth=\"${calc_digest}\""
    }
    if {[info exists data(digest,nc)]} {
	append auth_info [format ", nc=%08x" [expr 1 + $data(digest,nc)]]
    }

    # remember some data
    set digest(realm) $data(digest,realm)
    set digest(cnonce) $data(digest,cnonce)
    set digest(username) $data(digest,username)

    # associate nonce with realm,user
    global DigestByRealmName
    set DigestByRealmName($digest(realm),$digest(username)) $digest(nonce)

    Httpd_AddHeaders $sock Authentication-Info $auth_info

    #Stderr "Digest Request OK"
    return 1
}

# decode an Authentication request
# "parts" comes from the Authorization HTTP header.

proc Digest_Get {sock parts} {
    upvar #0 Httpd$sock data
    #Stderr "Digest_Get $parts"
    # get the digest request args
    foreach el [lrange $parts 1 end] {
	set el [string trimright $el ,]
	#foreach {n v} [split $el =] break
	regexp {^[ ]*([^=]+)[ ]*=[ ]*(.*)$} $el junk n v
	#Stderr "Getting: '$el' -> $n $v"
	set data(digest,[string trim $n " "]) [string trim $v " \""]
    }
    #Stderr "Digest Got: [array get data digest,*]"
    # perform some desultory checks on credentials
}

# create and issue a Digest challenge to the client
proc Digest_Challenge {sock realm user} {
    upvar #0 Httpd$sock data

    global DigestByRealmName
    if {[info exists DigestByRealmName($realm,$user)]} {
	# find an existing nonce for this realm,user pair
	set nonce $DigestByRealmName($realm,$user)

	upvar #0 Digest$nonce digest
	set digest(last) [clock clicks]	;# remember the last use
    } else {
	# get a new unique nonce
	# (redundant, really MD5 doesn't collide)
	set nonce [DigestNonce]
	while {[info exists ::Digest$nonce]} {
	    set nonce [DigestNonce]
	}
	upvar #0 Digest$nonce digest
	set digest(last) [clock clicks]	;# remember the last use

	# initialise the digest state
	global DigestSecret
	set digest(nonce) $nonce
	set digest(opaque) [string tolower [md5hex "[clock clicks]${DigestSecret}"]]
	#set digest(opaque) 5ccc069c403ebaf9f0171e9517f40e41	;# test
	set digest(nc) 0
	#set digest(stale) 0
    }

    # construct authentication args
    # minimally nonce, opaque, qop and algorithm
    set challenge [list nonce \"$digest(nonce)\" \
		       domain \"/" \
		       opaque \"$digest(opaque)\" \
		       qop \"auth\" \
		       algorithm MD5]
    #		   algorithm \"MD5,MD5-sess\"
    #if {$digest(stale)} {
    #lappend challenge stale true
    #}

    #Stderr "Digest Challenge: [array get digest] - $challenge"
    # issue Digest authentication challenge
    eval Httpd_RequestAuth $sock Digest $realm $challenge
}

if {0} {
    # test
    array set Httpd999 {
	digest,username Mufasa
	digest,realm testrealm@host.com
	digest,nonce dcd98b7102dd2f0e8b11d0f600bfb0c093
	uri /dir/index.html
	digest,uri /dir/index.html
	op GET
	digest,qop auth
	digest,nc 00000001
	digest,cnonce 0a4f113b
	digest,response 6629fae49393a05397450978507c4ef1
	digest,opaque 5ccc069c403ebaf9f0171e9517f40e41
	digest,algorithm MD5
    }
    array set Digest$Httpd999(digest,nonce) [list last [clock clicks] nc [format %08d 1] opaque $Httpd999(digest,opaque) nonce $Httpd999(digest,nonce) realm testrealm@host.com qop auth,auth-int passwd "Circle Of Life"]

    AuthParseHtaccess 999 /usr/lib/tclhttpd3.5.0/testdigest
    if {[catch {Digest_Request 999 testrealm@host.com /usr/lib/tclhttpd3.5.0/testdigest}  DTest]} {
	error "Digest test error"
    }
    if {$DTest != 1} {
	error "Failed digest test"
    }
}

# nb: mozilla converts UCS2 to UTF8 for username and password
