# dirlist.tcl --
#
# Create a HTML-formatted directory listing
#
# Steve Ball (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) dirlist.tcl 1.6 98/02/24 15:55:02

package provide dirlist 1.0
 
proc DirList {dir urlpath} {
    global tcl_platform
    upvar 1 sock sock	;# DISGUSTING HACK
    upvar #0 Httpd$sock data

    set sort name
    set pattern *
    if [info exists data(query)] {
	foreach {name value} [Url_DecodeQuery $data(query)] {
	    switch $name {
		sort {set sort $value}
		pattern {set pattern $value}
	    }
	}
    }
 
    if [string compare macintosh $tcl_platform(platform)] {
	set what Directory
	set lwhat directory
    } else {
	set what Folder
	set lwhat folder
    }
    set namecheck ""
    set sizecheck ""
    set numcheck ""
    switch -- $sort {
        number {
	    set numcheck checked
	}
	size {
	    set sizecheck checked
	}
	default {
	    set namecheck checked
	}
    }
    set listing "<HTML>
<HEAD>
<TITLE>Listing of $what $urlpath</TITLE>
</HEAD>
<BODY>
<H1>Listing of $what $urlpath</H1>

<form action=$urlpath>
Pattern <input type=text name=pattern value=$pattern><br>
Sort by Modify Date <input type=radio name=sort value=number $numcheck>
or Name <input type=radio name=sort value=name $namecheck>
or Size <input type=radio name=sort value=size $sizecheck><br>
<input type=submit name=submit value='Again'><p>
<PRE>
"

    set path [file split $dir]
    set list [glob -nocomplain -- [file join $dir $pattern]]
    if {[llength $path] > 1} {
	append listing \
	    "<A HREF=\"..\">Up to parent $lwhat</A>\n"
    }

    set timeformat "%b %e, %Y %X"
    if {[llength $list] > 0} {
	set max 0
	foreach entry $list {
	    setmax max [string length [file tail $entry]]
	}
	incr max [string length </a>]

	# Resort the list into list2

	switch -- $sort {
	    number {
		set mlist {}
		foreach entry $list {
		    lappend mlist [list $entry [file mtime $entry]]
		}
		if {[catch {lsort -decreasing -integer -index 1 $mlist} list2]} {
		    set list2 [lsort -command DateCompare $mlist]
		}
		set extra 1
	    }
	    size {
		set slist {}
		foreach entry $list {
		    lappend slist [list $entry [file size $entry]]
		}
		if {[catch {lsort -decreasing -integer -index 1 $slist} list2]} {
		    set list2 [lsort -command SizeCompare $slist]
		}
		set extra 1
	    }
	    default {
		if {[catch {lsort -dict $list} list2]} {
		    set list2 [lsort -command DirlistCompare $list]
		}
		set extra 0
	    }
	}

	# Loop through list2, which may have an extra sorting field we ignore

	foreach entry $list2 {
	    if {$extra} {
		set entry [lindex $entry 0]
	    }
	    file lstat $entry lst
	    switch $lst(type) {
		file {
		    # Should determine dingbat from file type
		    append listing "<A HREF=\"${urlpath}[file tail $entry]\">[format %-*s $max [file tail $entry]</a>] [format %8d $lst(size)] [format %-5s bytes]  [clock format $lst(mtime) -format $timeformat]\n"
		}
		directory {
		    append listing "<A HREF=\"${urlpath}[file tail $entry]/\">[format %-*s $max [file tail $entry]/</a>] [format %8s {}] [format %-5s dir]  [clock format $lst(mtime) -format $timeformat]\n"
		}
		link {
		    append listing "<A HREF=\"${urlpath}[file tail $entry]\">[format %-*s $max [file tail $entry]</a>] [format %8s {}] [format %-5s link]  [clock format $lst(mtime) -format $timeformat] -> [file readlink $entry]\n"
		}
		characterSpecial -
		blockSpecial -
		fifo -
		socket {
		    append listing "<A HREF=\"${urlpath}[file tail $entry]\">[format %-20s [file tail $entry]</a>] $lst(type)\n"
		}
	    }
	}
    } else {
	append listing "$what is empty\n"
    }
 
    append listing "
</PRE>
</FORM>
</BODY>
</HTML>
"
    return $listing
}

# DirlistCompare --
#
# Utility procedure for case-insensitive filename comparison.
# Suitable for use with lsort
 
proc DirlistCompare {a b} {
    string compare [string tolower $a] [string tolower $b]
}
 

proc DateCompare {a b} {
    set a [lindex $a 1]
    set b [lindex $b 1]
    if {$a > $b} {
	return -1
    } elseif {$a < $b} {
	return 1
    } else {
	return 0
    }
}
 
proc SizeCompare {a b} {
    set aa [lindex $a 1]
    set bb [lindex $b 1]
    set res [string compare $aa $bb]
    if { $res != 0 } {
	return $res
    } else {
	return [string compare $a $b]
    }
}
