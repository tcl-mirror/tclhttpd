# log.tcl
# Logging module for the Http server
# This starts a new log file each day with Log_SetFile
# It also maintains an error log file that is always appeneded to
# so it grows over time even when you restart the server.
#
# Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) log.tcl 1.5 97/06/26 15:10:52

package provide log 1.0

# log an Httpd transaction

###################################################
# Logging stuff for "standard" format
#  ip - - [date -tmz] "GET path HTTP/1.0" code bytes referrer agent

# Use IP address, or domain name?
# Default is IP address, because looking up names is expensive
if {![info exists Log(lognames)]} {
    set Log(lognames) 0
}

# This program is used to compress log files
if {![info exists Log(compressProg)]} {
    set Log(compressProg) /usr/local/bin/gzip
}

# Flush interval
if {![info exists Log(flushInterval)]} {
    set Log(flushInterval) [expr {60 * 1000}]
}


proc Log {sock reason args} {
    global Log
    upvar #0 Httpd$sock data

    # Log normal closes to the regular log.
    # Log everything else to the error log.

    switch -- $reason {
	"Close" {
	    set now [clock seconds]
	    if {$Log(lognames)} {
		# This is expensive, but low-volume sites may not care too much
		if {[catch {append result [Httpd_Peername $sock]}]} {
		    append result [LogValue data(ipaddr)]
		}
	    } else {
		append result	[LogValue data(ipaddr)]
	    }
	    append result { } [LogValue data(mime,auth-user)]
	    append result { } [LogValue data(mime,username)]
	    append result { } \[[clock format $now -format %d/%h/%Y:%T] -0700\]
	    append result { } \"[LogValue data(line)]\"
	    append result { } [LogValue data(code)]
	    append result { } [LogValue data(file_size)]
	    append result { } \"[LogValue data(mime,referer)]\"
	    append result { } \"[LogValue data(mime,user-agent)]\"
	    catch {puts $Log(log_fd) $result}
	    if {$Log(flushInterval) == 0} {
		catch {flush $Log(log_fd)}
	    }
	}
	default {
	    set now [clock seconds]
	    append result { } \[[clock format $now -format %d/%h/%Y:%T]\]
	    append result { } $sock { } $reason { } $args
	    if {[info exists data(url)]} {
		append result { } $data(url)
	    }
	    catch { puts $Log(error_fd)  $result ; flush $Log(error_fd) }
	}
    }
}

# Log_Configure --
#
#	Query/modify configuration settings for logging.
#
# Arguments:
#	args	option/value pairs
#
# Results:
#	Configuration value(s) or empty string

proc Log_Configure args {
    global Log

    switch [llength $args] {
	0 {
	    foreach {key value} [array get Log] {
		lappend result [list -$key $value]
	    }
	    return $result
	}
	1 {
	    return $Log(-[lindex $args 0])
	}
	default {
	    if {[llength $args] % 2} {
		error "no value specified for option \"[lindex $args end]\""
	    } else {
		foreach {option value} $args {
		    switch -- $option {
			-lognames {
			    lappend newOptions lognames [boolean $value]
			}
			default {
			    # TODO: Other logging options, such as filenames, flush interval, etc
			    error "unknown option \"$option\""
			}
		    }
		}
		array set Log $newOptions
	    }
	}
    }
    return {}
}

proc LogValue {var} {
    upvar $var data
    if {[info exists data]} {
	return $data
    } else {
       return -
    }
}

# Set the interval at which the logs are flushed.

proc Log_FlushMinutes {min} {
    global Log
    set Log(flushInterval) [expr $min*60*1000]
}

# Log_SetFile --
# automatically change log files every midnight

proc Log_SetFile {{basename {}}} {
    global Log
    if {[string length $basename]} {
	set Log(log) $basename
    }
    if {![info exists Log(log)]} {
	catch {close $Log(log_fd)}
	catch {close $Log(error_fd)}
	return
    }
    catch {Counter_CheckPoint} 		;# Save counter data

    # set after event to switch files after midnight
    set now [clock seconds]
    set next [expr {([clock scan 23:59:59 -base $now] -$now + 1000) * 1000}]
    after cancel Log_SetFile
    after $next Log_SetFile

    # set the log file and error file.
    # Log files rotate, error files don't

    if {[info exists Log(log_file)] && [file exists $Log(log_file)]} {
	set lastlog $Log(log_file)
    }
    set Log(log_file) $Log(log)[clock format $now -format %y.%m.%d]
    catch {close $Log(log_fd)}
    catch {set Log(log_fd) [open $Log(log_file) a]}

    if {[info exists lastlog]} {
	# compress log files as we go
	catch {exec $Log(compressProg) $lastlog &}
    }

    catch {close $Log(error_fd)}
    catch {set Log(error_fd) [open $Log(log)error a]}
}

# Log_Flush --
# flush the output to the log file.  Do this periodically, rather than
# for every transaction, for better performance

proc Log_Flush {} {
    global Log
    catch {flush $Log(log_fd)}
    catch {flush $Log(error_fd)}
    catch {after cancel $Log(flushID)}
    if {$Log(flushInterval) > 0} {
	set Log(flushID) [after $Log(flushInterval) Log_Flush]
    }
}

# Log_Array --
# Utility to dump an array to the log.

proc Log_Array {sock a} {
    global Log $a
    puts $Log(error_fd) [parray $a]
    flush $Log(error_fd)
}

