# template.tcl
#
# Support for generating HTML inside templates.
#
# Laurent Demailly / Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) template.tcl 1.8 98/02/24 16:06:33
#

package provide template 1.2

proc Head {} {
    global page
    set page(head) 1
    return "<HTML>\n<HEAD>\n<!-- This document has been generated - Don't edit this file,-->\n<!-- your changes would be LOST, edit the .tml file instead. -->\n"
}

proc Body {args} {
    global page
    set html ""
    if {[info exists page(head)]} {
	append html "</HEAD>\n"
    }
    append html "<BODY [join $args]>\n"
    set page(body) 1
    return $html
}

proc End {} {
    global page
    set html ""
    if {[info exists page(body)]} {
	append html "</BODY>\n"
    }
    if {[info exists page(head)]} {
	append html "</HTML>\n"
    }
    return $html
}

proc Title {str} {
    global page
    set page(title) $str
    return "<TITLE>$str</TITLE>\n"
}

proc Author {who} {
    global page
    set page(author) $who
    return "<!-- Author: $who -->\n"
}

proc Keywords {args} {
    return "<META NAME=\"keywords\" CONTENT=\"[join $args]\">\n"
}

proc ShowArray {arrname {pat *}} {
    upvar 1 $arrname arr
    set html ""
    if {[info exists arr]} {
	set html "<H2>$arrname array</H2>"
	append html <TABLE>
	foreach name [lsort [array names arr $pat]] {
	    append html "<TR><TD>$name</TD><TD>$arr($name)</TD></TR>\n"
	}
	append html </TABLE>
    }
    return $html
}
proc ShowQuery {querylist} {
    set html ""
    if {[llength $querylist]} {
	set html "<H2>Query Data</H2>"
	append html <TABLE>
	foreach {label value} $querylist {
	    append html "<TR><TD>$label</TD><TD>$value</TD></TR>\n"
	}
	append html </TABLE>
    }
    return $html
}

proc DynamicOnly {} {
    global page
    set page(dynamic) 1		;# Turns off caching the result
    return ""
}

proc Link {url {label ""}} {
    if {[string compare $label ""] == 0} {
	set label $url
    }
    return "<A HREF=\"$url\">$label</A>"
}

proc Email {addr} {
    return "<A HREF=\"mailto:$addr\">$addr</A>"
}

# To quote
proc Raw {string} {
    return $string
}

# returns and does nothing, useful for [set foo bar; Noop] or
# [Noop [set foo bar]] to avoid returning something into the .html

proc Noop {args} {
}

proc Path {name} {
    global page
    set dir [file dirname $page(filename)]
    return [file join $dir $name]
}

proc LastChange {{path ""}} {
    global page
    if {[string compare $path ""] == 0} {
	set path $page(template)
    } else {
	set path [Path $path]
    }
    return [clock format [file mtime $path] -format "%a %b %d %Y, %H:%M"]
}

proc RadioSet {varname args} {
    set html {}
    foreach label $args {
	append html "<input type=radio value=\"$label\" name=\"$varname\"> $label\n"
    }
    return $html
}
proc TclPower {{size 150} {align left}} {
    switch $size {
	75 {set flags "width=48 height=75"}
	100 {set flags "width=64 height=100"}
	150 {set flags "width=97 height=150"}
	175 {set flags "width=113 height=175"}
	200 {set flags "width=130 height=200"}
	default {set flags ""}
    }

    set html "<img src=/images/pwrdLogo$size.gif align=$align $flags>\n"
}

proc GetQueryData {aname args} {
    global page
    upvar 1 $aname array
    if {[info exists page(query)]} {
        array set query $page(query)
    } else {
        set query() {}
    }
    foreach item $args {
        set key [lindex $item 0]
        set default [lindex $item 1]
        if {[info exists query($key)]} {
            set array($key) $query($key)
        } else {
            set array($key) $default
        }
    }
}

