# status.tcl --
#
#	Application-direct URLs to give out status of the server.
# 	Tcl procedures of the form Status/hello implement URLS
#	of the form /status/hello
#
# Brent Welch (c) Copyright 1997 Sun Microsystems, Inc.
# Copyright 1998 Scriptics Corporation.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
package provide status 1.1

proc Status_Url {dir} {
    Direct_Url $dir Status
}

proc Status/hello {args} {return hello}

proc StatusSortForm {action label {pattern *} {sort number}} {
    if {[string compare $sort "number"] == 0} {
	set numcheck checked
	set namecheck ""
    } else {
	set numcheck ""
	set namecheck checked
    }
    append result "<form action=$action>"
    append result "Pattern <input type=text name=pattern value=$pattern><br>"
    append result "Sort by $label <input type=radio name=sort value=number $numcheck> or Name <input type=radio name=sort value=name $namecheck><br>"
    append result "<input type=submit name=submit value=\"Again\"><p>"
}

proc StatusMenu {} {
    set html "<p><a href=/status/>Status</a> |<a href=/status/doc>Doc hits</a> | <a href=/status/notfound>Doc misses</a><p>"
}

proc Status/doc {{pattern *} {sort number}} {
    set result ""
    append result "<h1>Document Hits</h1>\n"
    append result [StatusMenu]
    append result [StatusSortForm /status/doc "Hit Count" $pattern $sort]
    append result [StatusPrintHits $pattern $sort]
}
proc StatusPrintHits {{pattern *} {sort number}} {
    global counter cachehit
    catch {unset cachehit}
    foreach {name value} [array get counter cachehit,$pattern] {
	regsub {cachehit,} $name {} name
	if { ! [catch {expr {$value + 0}}]} {
	    set cachehit($name) $value
	}
    }
    append result [StatusPrintArray cachehit * $sort Hits Url]
}
proc StatusPrintArray {aname pattern sort col1 col2} {
    upvar 1 $aname a
    set result ""
    append result <pre>\n
    append result [format "%6s %s\n" $col1 $col2]
    set list {}
    set total 0
    foreach name [lsort [array names a $pattern]] {
	set value $a($name)
	lappend list [list $value $name]
	incr total $value
    }
    if {[string compare $sort "number"] == 0} {
	if [catch {lsort -index 0 -integer -decreasing $list} newlist] {
	    set newlist [lsort -command StatusSort $list]
	}
    } else {
	if [catch {lsort -index 1 -integer -decreasing $list} newlist] {
	    set newlist [lsort -command StatusSortName $list]
	}
    }
    append result [format "%6d %s\n" $total Total]
    foreach k $newlist {
	set url [lindex $k 1]
	append result [format "%6d %s\n" [lindex $k 0] $url]
    }
    append result </pre>\n
    return $result
}
proc StatusSort {a b} {
    set 1 [lindex $a 0]
    set 2 [lindex $b 0]
    if {$1 == $2} {
	return [string compare $a $b]
    } elseif {$1 < $2} {
	return 1
    } else {
	return -1
    }
}
proc StatusSortName {a b} {
    set 1 [lindex $a 1]
    set 2 [lindex $b 1]
    return [string compare $1 $2]
}

proc Status/notfound {{pattern *} {sort number}} {
    global Doc Referer
    set result ""
    append result "<h1>Documents Not Found</h1>\n"
    append result [StatusMenu]
    append result [StatusSortForm /status/notfound "Hit Count" $pattern $sort]
    append result [StatusPrintNotFound $pattern $sort]
}
proc StatusPrintNotFound {{pattern *} {sort number}} {
    global Doc Referer
    append result <pre>\n
    append result [format "%6s %s\n" Miss Url]
    set list {}
    foreach i [lsort [array names Doc notfound,$pattern]] {
	if ![catch {set Doc($i)} value] {
	    regsub {notfound,} $i {} j
	    lappend list [list $value $j]
	}
    }
    if [catch {lsort -index 0 -integer -decreasing $list} newlist] {
	set newlist [lsort -command StatusSort $list]
    }
    foreach k $newlist {
	set url [lindex $k 1]
	append result [format "%6d <a href=/admin/redirect?old=%s>%s</a>\n" \
	    [lindex $k 0] [lindex $k 1] [lindex $k 1]]
	if {[info exists Referer($url)]} {
	    set i 0
	    append result <ul>
	    foreach r $Referer($url) {
		append result "<li> <a href=\"$r\">$r</a>\n"
	    }
	    append result </ul>\n
	}
    }
    append result </pre>\n
#    append result "<a href=/status/notfound/reset>Reset counters</a>"
    return $result
}
proc Status/notfound/reset {args} {
    global Doc Referer
    foreach i [array names Doc notfound,*] {
	unset Doc($i)
    }
    catch {unset Referer}
    return "<h1>Reset Notfound Counters</h1>"
}
proc Status/size {args} {
    return [Status/datasize][Status/codesize]
}
proc Status/datasize {args} {
    set ng 0
    set nv 0
    set size 0
    foreach g [info globals *] {
	upvar #0 $g gg
	incr ng
	if [array exists gg] {
	    foreach {name value} [array get gg] {
		set size [expr {$size + [string length $name] + [string length $value]}]
		incr nv
	    }
	} else {
	    set size [expr {$size + [string length $g] + [string length $gg]}]
	    incr nv
	}
    }
    return "<h1>Data Size</h1>\n\
		Num Globals $ng<br>\n\
		Num Values $nv<br>\n\
		Data Bytes $size"
}
proc Status/codesize {args} {
    set np 0
    set size 0
    foreach g [info procs *] {
	incr np
	set size [expr {$size + [string length $g] +
			    [string length [info args $g]] +
			    [string length [info body $g]]}]
    }
    return "<h1>Code Size</h1>\n\
		Num Procs $np<br>\n\
		Code Bytes $size"
}
proc StatusMainTable {} {
    global Httpd Doc counter status tcl_patchLevel tcl_platform
    global counter_reset
    set html "<H1>$Httpd(name):$Httpd(port)</h1>\n"
    append html "<H2>Server Info</h2>"
    append html "<table border=0>"
    append html "<tr><td>Start Time</td><td>[clock format [Counter_StartTime]]</td></tr>\n"
    append html "<tr><td>Current Time</td><td>[clock format [clock seconds]]</td></tr>\n"
    append html "<tr><td>Server</td><td>$Httpd(server)</td></tr>\n"
    append html "<tr><td>Tcl Version</td><td>$tcl_patchLevel</td></tr>"
    switch $tcl_platform(platform) {
	unix {
	    append html "<tr><td colspan=2>[exec uname -a]</td></tr>"
	}
	macintosh -
	windows {
	    append html "<tr><td colspan=2>$tcl_platform(os) $tcl_platform(osVersion)</td></tr>"
	}
    }

    append html </table>

    append html "<br><br><br>\n"
    append html "<table border>\n"

    append html "<tr><th>Counter</th><th>N</th><th>Reset Date</th></tr>\n"
    foreach {c label} {
	    urlhits "URL Requests"
	    urlreply "URL Replies"
	    cachehit,/ "Home Page Hits"
	    accepts "Total Connections"
	    keepalive "KeepAlive Requests"
	    http1.0 "OneShot Connections"
	    http1.1 "Http1.1 Connections"
	    sockets "Open Sockets"
	    cgihits "CGI Hits"
	    tclhits "Tcl Safe-CGIO Hits"
	    maphits "Image Map Hits"
	    cancel	"Timeouts"
	    errors	"Errors"
	    Status	"Status"
	    } {
	set close ""
	if {[info exists counter($c)]} {
	    append html "<tr><td>$label</td><td>$counter($c)</td>\n"
	    set close "</tr>\n"
	}
	if {[info exists counter_reset($c)]} {
	    append html "<td>[clock format $counter_reset($c) -format "%B %d, %Y"]</td></tr>\n"
	}
	append html $close
    }
    append html </table>\n
    return $html
}

proc StatusTclPower {{align left}} {
    set html "<img src=/images/pwrdLogo150.gif align=$align width=97 height=150>\n"
}

proc Status/all {args} {
    global CntMinuteurlhits CntHoururlhits CntDayurlhits counter
    set html "<html><head><title>Tcl HTTPD Status</title></head>\n"
    append html "<body><h1>Tcl HTTPD Status</h1>\n"
    append html [StatusMenu]
    append html [StatusTclPower left]
    append html [StatusMainTable]
    append html "<p><a href=/status/text>Text only view.</a>\n"
    catch {
	append html [StatusMinuteHist CntMinuteurlhits "Per Minute Url Hits" $counter(basetime)]
	append html [StatusMinuteHist CntHoururlhits "Per Hour Url Hits" $counter(hour,1) hour]
	append html [StatusMinuteHist CntDayurlhits "Per Day Url Hits" $counter(day,1) day]
    }
    return $html
}
proc Status/text {args} {
    global CntMinuteurlhits CntHoururlhits CntDayurlhits counter
    set html "<title>Tcl HTTPD Status</title>\n"
    append html "<body><h1>Tcl HTTPD Status</h1>\n"
    append html [StatusMenu]
    append html [StatusTclPower left]
    append html [StatusMainTable]
    append html "<p><a href=/status/all>Bar Chart View.</a>"
    append html [StatusTimeText CntMinuteurlhits "Per Minute Url Hits" Min Hits $counter(basetime)]
    if [info exists CntHoururlhits] {
	append html [StatusTimeText CntHoururlhits "Per Hour Url Hits" Hour Hits $counter(hour,1)]
    }
    if [info exists CntDayurlhits] {
	append html [StatusTimeText CntDayurlhits "Per Day Url Hits" Day Hits $counter(day,1)]
    }
    return $html
}

proc Status/ {args} {
    eval Status/all $args
}
proc Status {args} {
    eval Status/all $args
}

proc Version {} {
    global tcl_patchLevel Httpd
    append html "$Httpd(server)"
    append html "<br>Tcl version $tcl_patchLevel"
    return $html
}

proc StatusMinuteHist {array title time {unit minute}} {
    global counter
    upvar #0 $array data
    if {! [info exists data]} {
	return ""
    }
    regsub ^Cnt $array Age agebitName
    upvar #0 $agebitName agebit

    set total 0
    set max 0
    set base 100
    foreach {name value} [array get data] {
	setmax max $value
    }
    switch $unit {
	minute	{set width 3}
	hour	{set width 5}
	day	{set width 5}
    }
    append result "<h3>$title ($max max)</h3>"
    append result <ul>
    append result "<h4>Starting at [clock format $time]</h4>"
    append result "<table cellpadding=0 cellspacing=0><tr>\n"
    set skip 0
    append result "<td valign=top>$max</td>\n"
    foreach t [lsort -integer [array names data]] {
	if {!$skip && [info exists agebit($t)]} {

	    # Indicate the hourly wrap-around point with a zero value.

	    set skip 1
	    set marker 1
	} else {
	    set marker 0
	}

	if {$unit == "hour" && ($t == $counter(mergehour))} {
	    set marker 1
	}
	set value $data($t)
	if {[catch {expr {round($value * 100.0 / $max)}} percent]} {
	    puts "Skipping $percent"
	    continue
	}
	set height [expr {$percent * $base / 100}]
	if {$marker} {
	    append result "<td valign=bottom><img src=/images/Red.gif height=$height width=$width XYZ></td>\n"
#	    append result "<td valign=bottom><hr size=$height width=$width></td>\n"
	} else {
	    append result "<td valign=bottom><img src=/images/Blue.gif  height=$height width=$width ABC></td>\n"
#	    append result "<td valign=bottom><hr NOSHADE size=$height width=$width></td>\n"
	}
    }
    append result "</tr>"

    switch $unit {
	minute	{#do nothing}
	hour	{
	    append result "<tr><td> </td>"
	    foreach t [lsort -integer [array names data]] {
		set tag td
		append result "<td><font size=1>[clock format $time -format %k]</font></td>"
		incr time 3600
	    }
	    append result </tr>
	}
	day {
	    append result "<tr><td> </td>"
	    set skip 4
	    set i 0
	    foreach t [lsort -integer [array names data]] {
		if {($i % $skip) == 0} {
		    append result "<td colspan=$skip><font size=1>[clock format $time -format "%h %e"]</font></td>"
		}
		incr time [expr 3600 * 24]
		incr i
	    }
	    append result </tr>
	}
    }
    append result "</table>"
    append result </ul>
    return $result
}

proc StatusTimeText {array title unit what time} {
    global counter
    upvar #0 $array data
    regsub ^Cnt $array Age agebitName
    upvar #0 $agebitName agebit
    set total 0
    set max 0
    set base 100
    foreach {name value} [array get data] {
	setmax max $value
    }
    switch $unit {
	Min	{set delta 60 ; set fmt %R}
	Hour	{set delta 3600 ; set fmt "%h %e %R"}
	Day	{set delta 86400 ; set fmt %D}
    }

    append result "<h3>$title ($max max)</h3>"
    append result <ul>
    append result "<h4>Starting at [clock format $time]</h4>"
    append result "<table cellpadding=2 cellspacing=2 border><tr>\n"
    append result "<tr><th>$unit</th><th>$what</th></tr>"
    foreach t [lsort -integer [array names data]] {
	set value $data($t)

	# Minutes time we infer from the starting time and the agebits,
	# which indicate minute buckets for the previous hour.

	if [info exists agebit($t)] {
	    set tt [expr $time - 3600]
	} else {
	    set tt $time
	}

	# Hours have their own base time in counter(hour,$hour)

	if {$unit == "Hour"} {
	    set tt $counter(hour,$t)
	}

	# Wrap separator

	if {[info exists lasttime] && ($lasttime > $tt)} {
	    append result "<tr><td><hr></td><td><hr></td></tr>"
	}
	set lasttime $tt
	append result "<tr><td>[clock format $tt -format $fmt]</td><td>$value</td></tr>"
	incr time $delta
    }
    append result "</table>"
    append result </ul>
    return $result
}

# Handle .stat templates. (NOTUSED)
# First process the incoming form data in an Status-specific way,
# then do a normal Subst into a safe interpreter
#   path:	The path name of the document
#   suffix:     The file suffix
#   sock:	The name of the socket, and a handle for the socket state

# It turns out this is not used, but you could use it as a template
# for your own application's template processor.

proc Doc_application/x-tcl-status {path suffix sock} {
    global status
    upvar #0 Httpd$sock data

    append data(query) ""
    set queryList [Url_DecodeQuery $data(query)]

    # Put the query data into an array.
    # If a key appears multiple times, the resultant array value will
    # be a list of all the values.

    foreach {name value} $queryList {
    	lappend query($name) $value
    }

    if ![info exists status(session)] {
	set status(session) [session_create Status]
    }

    # Process the query data from the previous page.

    if [catch {StatusProcess $session $queryList} result] {
	Httpd_ReturnData $sock text/html $result
	return
    } 

    # Expand the page in the correct session interpreter, or treat
    # the page as ordinary html if the session has ended.

    if {$result} {
	Doc_Subst $sock $path interp$session
    } else {
	Httpd_ReturnFile $sock text/html $path
    }
}

