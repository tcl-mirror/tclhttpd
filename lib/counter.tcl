# counter.tcl
#
# Global counters and histograms
#
# Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) counter.tcl 1.5 97/06/26 15:10:48

package provide counter 1.0

proc Counter_Init {} {
    global counter
    catch {unset counter}

    # starttime - beginning of time
    # basetime - base of minutes histogram
    # mergeday - index of day histogram
    # mergehour - index of hour histogram

    set counter(starttime) [set counter(basetime) [clock seconds]]
    set counter(mergeday) 0
    set counter(mergehour) 0

    set counter(mergetime) [expr 60 * 60 * 1000]
    after $counter(mergetime) CounterMergeHour
    Httpd_RegisterShutdown Counter_CheckPoint
}

proc Counter_StartTime {} {
    global counter
    return $counter(starttime)
}

proc Counter_CheckPoint {} {
    global counter CntDayurlhits CntHoururlhits CntMinuteurlhits
    Log {} \n[parray counter]
    Log {} \n[parray CntDayurlhits]
    Log {} \n[parray CntHoururlhits]
    Log {} \n[parray CntMinuteurlhits]
}

proc Count {what {delta 1}} {
    global counter
    if [catch {incr counter($what) $delta}] {
	set counter($what) $delta
    }
    return $counter($what)
}

proc Counter_Reset {what {where 0}} {
    global counter
    set counter($what) $where
}

proc Counter_Get {{pat *}} {
    global counter
    array get counter $pat
}

proc CountHist {what {delta 1}} {
    global counter
    upvar #0 CntMinute$what histogram
    upvar #0 AgeMinute$what agebit
    set minute [expr ([clock seconds] - $counter(basetime)) / 60]
    if {[info exists histogram($minute)] && ![info exists agebit($minute)]} {
	incr histogram($minute)
    } else {
	set histogram($minute) $delta
	if [info exists agebit($minute)] {
	    unset agebit($minute)
	}
    }
    Count $what $delta
}

proc CounterMergeHour {} {
    global counter

    # Save the minutes histogram into a bucket for the last hour
    # counter(hour,$hour) is the starting time for that hour bucket

    upvar 0 counter(mergehour) hour
    set hour [expr ($hour % 24) + 1]
    set counter(hour,$hour) $counter(basetime)
    set counter(basetime) [clock seconds]

    foreach a [info globals CntMinute*] {
	regexp {CntMinute(.*)} $a x what
	upvar #0 CntHour$what hourhist
	upvar #0 CntMinute$what histogram
	upvar #0 AgeMinute$what agebit
	set hourhist($hour) 0
	foreach i [array names histogram] {
	    if ![info exists agebit($i)] {
		incr hourhist($hour) $histogram($i)
	    }
	    set agebit($i) 1
	}
    }
    if {$hour >= 24} {
	CounterMergeDay
    }

    # Set up the merge to happen on the hour

    set secs [clock seconds]
    set lasthour [clock scan [clock format $secs -format %H]]
    set secs [expr (60 * 60) - ($secs - $lasthour)]
    if {$secs <= 60} {
	set secs [expr (60 * 60)]
    }
    after [expr $secs * 1000] CounterMergeHour
}

proc CounterMergeDay {} {
    global counter

    # Save the hours histogram into a bucket for the last day
    # counter(day,$day) is the starting time for that day bucket

    set day [incr counter(mergeday)]
    set counter(day,$day) $counter(hour,1)
    foreach a [info globals CntHour*] {
	regexp {CntHour(.*)} $a x what
	upvar #0 CntDay$what dayhist
	upvar #0 CntHour$what hourhist
	set dayhist($day) 0
	for {set i 1} {$i <= 24} {incr i} {
	    catch {incr dayhist($day) $hourhist($i)}
	}
    }
}
