#!/usr/local/bin/tclsh8.0

package provide form 1.0

namespace eval form:: {
    # create namespace
    variable btag <p>	;# Could be <li>

    variable qnum

    # Define form element sizes

    variable cols	45
    variable lines	8

    namespace export *
}

proc form::text {lines name question {value {}}} {
    variable btag
    variable cols
    if {$lines == 1} {
	set html "$btag$question\n<br><input type=text name=\"$name\" size=$cols value=\"$value\">\n"
    } else {
	set html "$btag$question\n<br><textarea name=\"$name\" cols=$cols rows=$lines>$value</textarea>\n"
    }
    return $html
}

proc form::checkbox {name question {value yes}} {
    variable btag
    set html "$btag<input type=checkbox name=\"$name\" value=$value> $question\n\n"
}

proc form::selectplain {name size choices} {
    set namevalue {}
    foreach c $choices {
	lappend namevalue $c $c
    }
    return [form::select $name $size $namevalue]
}

proc form::select {name size choices} {
    global page

    if {![form::empty $name]} {
	array set query $page(query)
	set current $query($name)
    } else {
	set current ""
    }
    set html "<select name=\"$name\" size=$size>\n"
    foreach {v label} $choices {
	if {[string match $current $v] || ([llength $choices] <= 2)} {
	    set SEL SELECTED
	} else {
	    set SEL ""
	}
	append html "<option value=\"$v\" $SEL>$label\n"
    }
    append html "</select>\n"
    return $html
}

proc form::classboxStart {} {
    set html "<table cellpadding=2>\n<tr valign=top><th>Course Description</th><th># Students</th><th>Travel?</th></tr>\n"
}

proc form::classbox {name desc} {
    append html "<tr><td><input type=checkbox name=\"$name\" value=yes> $desc</td>\n"
    append html "<td><input type=text name=\"${name}_size\" size=6></td>\n"
    append html "<td><input type=checkbox name=\"{$name}_travel\" value=yes></td>\n"
    append html </tr>\n
}
proc form::classboxEnd {} {
    set html "</table>"
}



proc form::submit {label {name submit}} {
    variable btag
    set html "$btag<input type=submit name=\"$name\" value=\"$label\">\n"
}

# Return a name and value pair, where the value is initialized
# from existing form data, if any.

proc form::value {name} {
    global page
    if {[catch {array set query $page(query)}] ||
	![info exist query($name)]} {
	return "name=$name value=\"\""
    }
    regsub -all {"} $query($name) {\&#34;} value
    regsub -all {'} $value {\&#39;} value
    regsub -all {<} $value {\&lt;} value
    regsub -all {>} $value {\&gt;} value
    return "name=$name value=\"$value\""
}

# Return a form value, or "" if the element is not defined in the query data.

proc form::data {name} {
    global page
    if {[catch {array set query $page(query)}] ||
	![info exist query($name)]} {
	return ""
    }
    return $query($name)
}

# Like form::value, but for checkboxes that need CHECKED

proc form::checkvalue {name {value 1}} {
    global page
    if {[catch {array set query $page(query)}] ||
	    ![info exist query($name)]} {
	return "name=$name value=\"$value\""
    }
    foreach {n v} $page(query) {
	if {[string compare $name $n] == 0 &&
		[string compare $value $v] == 0} {
	    return "name=$name value=\"$value\" CHECKED"
	}
    }
    return "name=$name value=\"$value\""
}

# Like form::value, but for radioboxes that need CHECKED

proc form::radiovalue {name value} {
    global page
    if {[catch {array set query $page(query)}] ||
	    ![info exist query($name)] ||
	    [string compare $query($name) $value] != 0} {
	return "name=$name value=\"$value\""
    }
    return "name=$name value=\"$value\" CHECKED"
}

# form::radioset --
#
#	Display a set of radio buttons while looking for an existing
#	value from the query data, if any.

proc form::radioset {key sep list} {
    global page
    array set query $page(query)
    set html "<!-- radioset $key $page(query) -->\n"
    foreach {v label} $list {
	if {![form::empty $key] &&
		[string match $v $query($key)]} {
	    set SEL CHECKED
	} else {
	    set SEL ""
	}
	append html "<input type=radio name=$key value=$v $SEL> $label$sep"
    }
    return $html
}

# form::checkset --
#
#	Display a set of check buttons while looking for an existing
#	value from the query data, if any.

proc form::checkset {key sep list} {
    global page
    array set query $page(query)
    foreach {v label} $list {
	if {![empty query($key)] &&
		[lsearch $query($key) $v] >= 0} {
	    set SEL CHECKED
	} else {
	    set SEL ""
	}
	append html "<input type=checkbox name=$key value=$v $SEL> $label$sep"
    }
    return $html
}

# form::line --
#
#	Display an entry in a table row

proc form::line {name question {value {}}} {
    set html "<tr><td>$question\n</td><td><input type=text size=30 [form::value $name]></td></tr>\n"
    return $html
}

# form::empty --
#
#	Return true if the variable doesn't exist or is an empty string

proc form::empty {name} {
    global page
    if {[info exist page(query)]} {
	array set query $page(query)
    }
    return [expr {![info exist query($name)] || 
	[string length [string trim $query($name)]] == 0}]
}

# Pick up the fields from the previous form(s)

proc form::getFormInfo {} {
    global page
    set html ""
    if {![info exist page(query)]} {
	return "<!-- no query data -->\n"
    }
    foreach {name value} $page(query) {
	if {[string match submit_* $name] || [string match token $name]} {
	    continue
	}
	append html "<input type=hidden name=\"$name\" value=\"$value\">\n"
    }
    return $html
}

proc form::startNumber {i} {
    variable qnum $i
}
proc form::incrNumber {} {
    variable qnum
    incr qnum
}
