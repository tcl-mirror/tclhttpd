# Simplified Certificate Authority code for generating
# server and CA certificates, suitable for tclhttpd and tls

# Note: we do not encrypt the private keys we generate.
# if this troubles you (and it probably should):
# store $CA(CAdir)/private on an encrypted mount.

# Under tclhttpd, we generate a little CA directory with server and CA certs
# and a directory [Doc_Root]/ca/ containing those keys, to enable a client
# to trust the CA key so our server key will go down easy.

if {[info proc tls::init] == ""} {
    # sourced into a virtual host's interp - do nothing
    return
}

# Configuration for CA
# Edit to suit - particularly the CA_* fields

if {[info exists ::Httpd]} {
    set CA(CAhost) $Config(https_host)	;# https host
    set CA(CAdir) "/etc/tclhttpd/CA"	;# directory for xCA information
    set CA(openssl) "/usr/bin/openssl"	;# your openssl executable

    # web-accessible CA certificates
    array set CA [subst {
	URL "http://$CA(CAhost)/ca/"
	Web [file join [Doc_Root] ca]
	OCSP "http://$CA(CAhost)/oscp"
    }]

    array set CA [subst {
	keybits 2048
	CA_C "AU"
	CA_ST "NSW"
	CA_L "Sydney"
	CA_O "Tclhttpd CA"
	CA_OU "Certificate Authority"
	CA_CN $CA(CAhost)
    }]
		  
    array set CA {
	SSL_REQUEST 0
	SSL_REQUIRE 0
	USE_SSL2 1
	USE_SSL3 1
	USE_TLS1 1
	SSL_CIPHERS {}
    }
}

# run the openssl program
proc openssl {args} {
    global CA
    #Stderr "openssl: $args"
    return [eval exec $CA(openssl) $args 2>[file join $CA(CAdir) stderr]]
}

# start a config section
proc CAsection {var section body} {
    upvar $var cnf
    dict set cnf $section [uplevel 1 subst [list $body]]
}

# emit an openssl.cnf file from our dict
proc CAemit {file dict} {
    set fd [open $file w]
    dict for {id section} $dict {
	puts $fd "\[${id}\]"
	dict for {var val} $section {
	    if {[string match "* *" $val]} {
		set val "\"${val}\""
	    }
	    puts $fd "\t$var = $val"
	}
	puts $fd ""
    }
    close $fd
}

# generate the Certificate Authority keys and self-signed certificate
proc CA_GenCA {subject} {
    global CA
    upvar 1 $subject subj

    # sadly, we have to use ::env to pass config args
    foreach var {C ST L O OU CN} {
	if {[info exists subj(CA_$var)]} {
	    set ::env(CA_$var) $subj(CA_$var)
	} elseif {[info exists CA(CA_$var)]} {
	    set ::env(CA_$var) $CA(CA_$var)
	} else {
	    set ::env(CA_$var) ""
	}
    }

    # generate a new request
    set dir $CA(CAdir)
    set serial ca	;# get serial number of cert
    set where [file join $dir newcerts $serial]
 
    # create CA's key and self-signed certificate
    openssl req -x509 -nodes -batch \
	-config [file join $dir ca.cnf] \
	-newkey rsa:$CA(keybits) -keyout ${where}.key \
	-extensions v3_ca \
	-days [expr {365 * 5}] \
	-out ${where}.cacert

    # don't pollute ::env - it's bad enough that we have to use it at all
    foreach var {C ST L O OU CN} {
	unset ::env(CA_$var)
    }

    return $where
}

# get the CA serial number
proc CAgetSN {} {
    global CA
    set serial [file join $CA(CAdir) serial]
    set fd [open $serial]
    set sn [gets $fd]
    close $fd
    return $sn
}

# generate a user or server certificate where we 
# hold the keypair - not suitable for secure user certificates
proc CA_GenCert {subject {type usr}} {
    global CA
    upvar 1 $subject subj

    # sadly, we have to use ::env to pass config args
    foreach var {C ST L O OU CN} {
	if {[info exists subj(CA_$var)]} {
	    set ::env(CA_$var) $subj(CA_$var)
	} elseif {[info exists CA(CA_$var)]} {
	    set ::env(CA_$var) $CA(CA_$var)
	} else {
	    set ::env(CA_$var) ""
	}
    }

    # generate a new request
    set dir $CA(CAdir)
    set serial [CAgetSN]	;# get serial number of cert
    set where [file join $dir newcerts $serial]

    if {$type eq "server"} {
	# we must create servers' and CA's key
	set arg [list -newkey rsa:$CA(keybits) -keyout ${where}.key]
    } else {
	set arg {}
    }

    lappend arg -nodes -batch \
	-config [file join $dir ca.cnf] \
	-extensions v3_$type \
	-days [expr {365 * 5}] \
	-out ${where}.req

    eval openssl req $arg 

    openssl ca -batch -notext \
	-config [file join $dir ca.cnf] \
	-outdir [file join $dir newcerts] \
	-infiles ${where}.req

    #-out ${where}.ucert \

    # don't pollute ::env - it's bad enough that we have to use it at all
    foreach var {C ST L O OU CN} {
	unset ::env(CA_$var)
    }

    return $where
}

# Generate a User certificate:
# insecure, because we generate the keypair
proc CA_User {CN} {
    global CA
    set dir [file normalize $CA(CAdir)]
    set subject(CA_CN) $CN
    set subject(CA_OU) "User"
    CA_GenCert subject
}

# Generate a Server certificate for server named $CN
proc CA_Server {CN} {
    global CA
    set dir [file normalize $CA(CAdir)]
    set where [file join $dir private $CN]

    if {[file exists $where.ucert]} {
	Stderr "Server cert $CN already set up"
	return $where
    }

    set subject(CA_CN) $CN
    set subject(CA_OU) "Server"
    set cert [CA_GenCert subject server] 

    file link -symbolic $where.ucert ${cert}.pem
    file rename -force ${cert}.key $where.key
    return $where
}

# initialize the Certificate Authority
proc CA_Init {} {
    global CA

    set dir [file normalize $CA(CAdir)]
    set cacert [file join $dir private ca]

    set serial [file join $dir serial]
    if {[file exists $serial]} {
	Stderr "CA already set up"
	return 0
    }

    # certificate revocation directory
    file mkdir [file join $dir crl]

    # new requests directory
    file mkdir [file join $dir requests]

    # new certificate directory
    file mkdir [file join $dir newcerts]

    # private directory
    file mkdir [file join $dir private]
    file attributes $dir -permissions 0770	;# make private private

    # directory for trusted CAs for [tls -cadir]
    file mkdir [file join $dir trusted]

    # directory for spkac requests
    file mkdir [file join $dir spkac]

    # create a serial file
    set fd [open $serial w]
    puts $fd "01"
    close $fd

    # create a crlnumber file
    set crlnumber [file join $dir crlnumber]
    set fd [open $crlnumber w]
    puts $fd "0"
    close $fd

    # create an empty index file
    set fd [open [file join $dir index.txt] w]
    close $fd

    # construct some config files
    set ca_cnf [dict create]

    CAsection ca_cnf ca {
	default_ca CA_default
    }
	
    CAsection ca_cnf CA_default {
	dir $dir
	certs [file join $dir certs]
	database [file join $dir index.txt]
	new_certs_dir [file join $dir newcerts]
	certificate [file join $dir private ca.cacert]
	serial [file join $dir serial]
	
	crl [file join $dir crl]
	crlnumber [file join $dir crlnumber]
	crl_extensions crl_ext
	default_crl_days 30
	
	private_key [file join $dir private ca.key]
	RANDFILE [file join $dir private .rnd]
	x509_extensions v3_usr
	name_opt ca_default
	cert_opt ca_default
	default_days 365
	default_md md5
	preserve no
	policy policy_match
    }
    
    CAsection ca_cnf crl_ext {
	issuerAltName "issuer:copy"
	authorityKeyIdentifier "keyid,issuer:always"
    }

    CAsection ca_cnf policy_match {
	countryName match
	stateOrProvinceName match
	organizationName	 match
	organizationalUnitName optional
	commonName supplied
	emailAddress optional
    }
    
    CAsection ca_cnf policy_anything {
	countryName optional
	stateOrProvinceName optional
	localityName optional
	organizationName optional
	organizationalUnitName optional
	commonName supplied
	emailAddress optional
    }

    CAsection ca_cnf req {
	default_bits $CA(keybits)
	default_keyfile priv.key
	distinguished_name req_distinguished_name
	x509_extensions v3_ca
	prompt no
	req_extensions v3_req
	email_in_dn no 
    }

    CAsection ca_cnf v3_req {
	basicConstraints "critical, CA:FALSE"
	keyUsage "nonRepudiation, digitalSignature, keyEncipherment"
    }

    CAsection ca_cnf req_distinguished_name {
	C "\$ENV::CA_C"
	ST "\$ENV::CA_ST"
	L "\$ENV::CA_L"
	O "\$ENV::CA_O"
	OU "\$ENV::CA_OU"
	CN "\$ENV::CA_CN"
    }

    CAsection ca_cnf v3_ca {
	subjectKeyIdentifier hash
	authorityKeyIdentifier "keyid,issuer:always"
	basicConstraints  "critical, CA:true"
	keyUsage "cRLSign, keyCertSign, digitalSignature, nonRepudiation"
	issuerAltName "issuer:copy"
	subjectAltName "email:copy"
	nsCertType "sslCA, emailCA, objCA"
	nsComment "TclHttpd CA Certificate"
	nsBaseUrl $CA(URL)
    }

    # x509 extensions that broke
    #authorityInfoAccess "OCSP;URI:[file join $CA(URL) ocsp]"
    #nsCaRevocationUrl [file join $CA(URL) ca.crl]
    #crlDistributionPoints "URI:[file join $CA(URL)]"

    # create x509 extensions for each class of generated certificates
    foreach {class perms} {server "sslServer, objsign"
	objsign "objsign"
	usr "client, email"
	everything "client, email, objsign"
    } {
	CAsection ca_cnf v3_${class} {
	    subjectKeyIdentifier hash
	    authorityKeyIdentifier "keyid,issuer:always"
	    basicConstraints CA:FALSE
	    keyUsage "nonRepudiation, digitalSignature, keyEncipherment"
	    subjectAltName "email:copy"
	    issuerAltName "issuer:copy"
	    nsComment "TclHttpd Generated Certificate"
	    nsBaseUrl $CA(URL)
	}
    }

    # x509 extensions that broke
    #authorityInfoAccess "OCSP;URI:[file join $CA(URL) ocsp]"
    #nsCertType "$perms"
    #crlDistributionPoints "URI:[file join $CA(URL) ca.crl]"
    #nsCaRevocationUrl "[file join $CA(URL)]"

    CAemit [file join $dir ca.cnf] $ca_cnf

    # generate the CA certificate
    array set subject {}
    set where [CA_GenCA subject] 
    file rename ${where}.cacert [file join $dir private ca].cacert
    file rename ${where}.key [file join $dir private ca].key

    # we trust our own CA certificate
    CAtrust $cacert.cacert "../private/ca.cacert"
    return $cacert
}

# provide symlink for tls CAdir handling
# (qv c_rehash PERL script from openssl)
proc CAtrust {cacert {cafn ""}} {
    if {$cafn == ""} {
	# by default, cafn is cacert,
	# but we allow caller to link to (e.g.) a relative fn.
	set cafn $cacert
    }

    global CA
    set CAtrust [file join $CA(CAdir) trusted]
    set x [openssl x509 -hash -fingerprint -noout -in $cacert]
    set hash [lindex [split $x "\n"] 0]
    set suffix 0
    while {[file exists [file join $CAtrust $hash].$suffix]} {
	incr suffix
    }
    file link -symbolic [file join $CAtrust $hash].$suffix $cafn
}

if {[info exists ::Httpd]} {
    # mangle the default startup message
    set startup "[join [lrange [split $startup \n] 0 end-1]] \n]\n"

    if {[catch {
	# tclhttpd setup

	# set up types for certificates
	Mtype_Add .cacert application/x-x509-ca-cert
	Mtype_Add .ucert application/x-x509-user-cert

	# initialize the Certificate Authority
	set cacert [CA_Init]
	
	# make server certificate
	set cert [CA_Server $CA(CAhost)]
	    
	# now make a web-accessible ca directory
	# which can deliver our certificates
	if {![file exists $CA(Web)]} {
	    file mkdir $CA(Web)
	    file link -symbolic [file join $CA(Web) $CA(CAhost).ucert] $cert.ucert
	    file link -symbolic [file join $CA(Web) ca.cacert] $cacert.cacert
	}

	tls::init -request $CA(SSL_REQUEST) \
	    -require $CA(SSL_REQUIRE) \
	    -ssl2 $CA(USE_SSL2) \
	    -ssl3 $CA(USE_SSL3) \
	    -tls1 $CA(USE_TLS1) \
	    -cipher $CA(SSL_CIPHERS) \
	    -cadir [file join $CA(CAdir) trusted] \
	    -cafile [file join $CA(CAdir) private ca.cacert] \
	    -certfile $cert.ucert \
	    -keyfile $cert.key
	
	Httpd_SecureServer $Config(https_port) $Config(https_host) $Config(https_ipaddr)

	# hijack the default startup message
	append startup "secure httpd started on SSL port $Config(https_port)\n"
    } err eo]} {
	# hijack the default startup message
	append startup "SSL startup failed: $err"
    }

} else {
    # not loaded under tclhttpd - do something else
    if {![info exists CA(CAdir)]} {
	set CA(CAhost) "localhost"
	set CA(CAdir) "/etc/tclhttpd/CA"
    }

    array set CA [subst {
	URL "http://$CA(CAhost)/ca/"
	OCSP "http://$CA(CAhost)/oscp"
	keybits 2048
	openssl /usr/bin/openssl
	CA_C AU
	CA_ST "NSW"
	CA_L "Sydney"
	CA_O "Tclhttpd CA"
	CA_OU "CA Certificate"
	CA_CN $CA(CAhost)
    }]
    puts stderr "CA Loaded"
}

if {[info exists argv0] && ([info script] == $argv0)} {
    # unit test - standalone load
    set CA(CAdir) [file join [pwd] CA]
    CA_Init
    puts stderr "Initialised"
    CA_Server localhost
    CA_User "A User"
}
