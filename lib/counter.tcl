# counter.tcl
#
# Global counters and histograms
#
# This module was generalized and moved into the Standard Tcl Library.
# This code is now a thin layer over that more general package.
#
# We pre-declare any non-simple counters (e.g., the time-based
# histogram for urlhits, and the interval-histogram for service times)
# and everything else defaults to a basic counter.  Once things
# are declared, the counter::count function counts things for us.
#
# Brent Welch (c) 1997 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: counter.tcl,v 1.13 2000/10/03 03:51:45 welch Exp $

# Layer ourselves on top of the Standard Tcl Library counter package.

package require counter 2.0
package provide httpd::counter 2.0

proc Counter_Init {{secsPerMinute 60}} {
    global counter
    global counterTags
    if {[info exists counter]} {
	unset counter
    }
    set counter(starttime) [clock seconds]
    
    # The Count procedure will be self-initializing because
    # the counter::count module is not.  The knownTags list is
    # searched to determine if we need to initialize the counter.
    # Predefine well known counters here.

    # urlhits is the number of requests serviced.

    set counterTags(urlhits) 1
    counter::init urlhits -timehist $secsPerMinute

    # This start/stop timer is used for connection service times.
    # The linear histogram has buckets of 5 msec.

    set counterTags(serviceTime) 1
    counter::init serviceTime -hist 0.005

    # This log-scale histogram multiplies the seconds time by
    # 1000 to get milliseconds, and then plots the log of that.
    # The log-base histgram isn't useful
    #counter::init serviceTime -histlog 10

    # These group counters are used for per-page hit, notfound, and error
    # statistics.  If you auto-gen unique URLS, these are a memory leak
    # that you can plug by doing
    #
    #	status::countInit hit -simple

    foreach g {domainHit hit notfound error} {
	counter::init $g -group $g
	set counterTags($g) 1
    }

    # These are simple counters about each kind of connection event

    foreach c {accepts sockets connections urlreply keepalive connclose 
		http1.0 http1.1} {
	counter::init $c
	set counterTags($c) 1
    }
    Httpd_RegisterShutdown Counter_CheckPoint
}

proc Counter_CheckPoint {} {
    global Log
    if {[info exists Log(log)]} {
	set path $Log(log)counter
	catch {file rename -force $path $path.old}
	if {![catch {open $path w} out]} {
	    puts $out \n[parray counter]
	    puts $out \n[parray [counter::get urlhits -histVar]]
	    puts $out \n[parray [counter::get urlhits -histHourVar]]
	    puts $out \n[parray [counter::get urlhits -histDayVar]]
	    close $out
	}
    }
}

proc Count {what {delta 1}} {
    global counterTags
    if {![info exist counterTags($what)]} {
	counter::init $what
    }
    counter::count $what $delta
}

proc CountName {instance tag} {
    counter::count $tag 1 $instance
}

proc Counter_Reset {what args} {
    eval {counter::reset $what} $args
}

proc CountHist {what {delta 1}} {
    counter::count $what $delta
}

proc CountStart {what instance} {
    counter::start $what $instance
}
proc CountStop {what instance} {
    counter::stop $what $instance
#    counter::stop $what $instance CountMsec
}
proc CountMsec {x} {
    return [expr {$x * 1000}]
}
proc CountVarName {what} {
    return [counter::get $what -totalVar]
}
proc Counter_StartTime {} {
    return $counter::startTime
}
