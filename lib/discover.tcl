# Snmp discovery

# Stephen Uhler  (c) 1997 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: discover.tcl,v 1.2 2000/08/02 07:06:52 welch Exp $

package provide httpd::snmp 1.0

# Get my ip address.
 
proc MyIpaddr {} {
    set addr ""
    if {[catch {dns address [info hostname]} addr]} {
        set server [socket -server # 0]
        set port [lindex [fconfigure $server -sockname] 2]
        set host [lindex [fconfigure $server -sockname] 1]
        set client [socket $host $port]
        set addr [lindex [fconfigure $client -sockname] 0]
        close $client
        close $server
    }
    return $addr
}

# Return the network part of the address (assume class C).

proc MyNet {} {
    set net ""
    regexp {(.*)\..*} [MyIpaddr] {} net
    return $net
}

# Look for all snmp hosts on a  (class C) network.
# Return an array containing the discovery info.

proc SnmpDiscover {{net {}}  {callback #} {delay 25} {window 255}
		    {retries 3} {timeout 7}} {
    if {$net == {}} {
	set net [MyNet]
    }
    for {set i 1} {$i < 255} {incr i} {
        set s [snmp session -address $net.$i -delay $delay -window $window \
               -retries $retries -timeout $timeout]
        $s get sysDescr.0 [list DiscoverCallback $net $i $callback %S %E %V] 
        update
    }
    snmp wait
}

# Callback point for SnmpDiscover
#   net:  which network
#   session: the token for the snmp session
#   error:   the error string
#   descr:   the result of the query

proc DiscoverCallback {net host callback session error {desc {}}} {
    upvar #0 Discover:$net discover
    #Stderr "Discover $net $host $error"
    if {$error == "noError"} {
	catch {$callback $net $host found}
        regsub -all "\[\n\r\]" [lindex $desc 2] "" d
        if [catch {$session get sysName.0} name] {
            set name (unknown)
        }
        set name [lindex [lindex $name 0] end]
        set discover([$session cget -address]) [list $d $name]
    } else {
	catch {$callback $net $host "not found"}
    }
    $session destroy
}
