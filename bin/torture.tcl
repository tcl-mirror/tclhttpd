# Sample Exorsizer for Http servers
# Stephen Uhler (c) 1996 Sun Microsystems

# Fetch a document many times, simultaneously

proc Spray {server port count args} {
    global max finish done start total null
    set max $count
    set done 0
    set total 0
    puts "Starting $count fetches"
    set start [clock clicks]
    while {[incr count -1] >=0} {
	if {[catch {socket $server $port} s]} {
	    set max [expr $max - $count]
	    puts "Only $max fetches started"
	    puts ($s)
	    break
	}
	fconfigure $s -block 0
	puts $s "GET [lindex $args [expr $count%[llength $args]]] HTTP/1.0"
    	puts $s "User-agent: Tcl-Web-tester"
    	puts $s "Accept: */*"
	puts $s ""
	flush $s
	set null [open /dev/null w]
	if {[info commands fcopy] == "fcopy"} {
	    fcopy $s $null -command [list CopyDone $s $null]
	} else {
	    fileevent $s readable [list Read $s $null]
	}
    }
    vwait finish
    Report $max
}

proc Report {max} {
    global start total
    set us [expr { [clock clicks] - $start}]
    puts "[expr $us/1000]ms $total bytes $max fetches"
    puts "[expr $us/$max/1000.0] ms/fetch"
    puts "[expr $total/($us/1000000.0)] bytes/sec"
    puts "[expr $max/($us/1000000.0)] fetches/sec"
    puts "[expr $total/$max] bytes/fetch"
}
# file-event handler

proc Read {s null} {
    global start total
    if [eof $s] {
	CopyDone $s $null
    } else {
	incr total [unsupported0 $s $null]
    }
}

proc CopyDone {s null {bytes 0} {error {}}} {
    global done max finish total
    close $s
    close $null
    incr total $bytes
    if {[incr done] == $max} {
	set finish 1
    }
}

proc Iterate {server port count args} {
    global max finish done start total
    set countOrig $count
    set total 0
    puts "Starting $count fetches"
    set start [clock clicks]
    while {[incr count -1] >=0} {
	set max 1
	set done 0
	if {[catch {socket $server $port} s]} {
	    set countOrig [expr $max - $count]
	    puts "Only $countOrig fetches started"
	    puts ($s)
	    break
	}
	fconfigure $s -block 0
	puts $s "GET [lindex $args [expr $count%[llength $args]]] HTTP/1.0"
    	puts $s "User-agent: Tcl-Web-tester"
    	puts $s "Accept: */*"
	puts $s ""
	flush $s
	set null [open /dev/null w]
	if {[info commands fcopy] == "fcopy"} {
	    fcopy $s $null -command [list CopyDone $s $null]
	} else {
	    fileevent $s readable [list Read $s $null]
	}
	vwait finish
    }
    Report $countOrig
}

