# html.tcl
# Support routines for working with HTML tags

package provide html 1.0

# Extract a value from parameter list (this needs a re-do)
# returns "1" if the keyword is found, "0" otherwise
#   param:  A parameter list.  It should alredy have been processed to
#           remove any entity references
#   key:    The parameter name
#   val:    The variable to put the value into (use key as default)

proc Html_ExtractParam {param key {val ""}} {
    if {$val == ""} {
	upvar $key result
    } else {
	upvar $val result
    }
    set ws " \t\n\r"
 
    # look for name=value combinations.  Either (') or (") are valid delimeters
    if {
      [regsub -nocase [format {.*%s[%s]*=[%s]*"([^"]*).*} $key $ws $ws] $param {\1} value] ||
      [regsub -nocase [format {.*%s[%s]*=[%s]*'([^']*).*} $key $ws $ws] $param {\1} value] ||
      [regsub -nocase [format {.*%s[%s]*=[%s]*([^%s]+).*} $key $ws $ws $ws] $param {\1} value] } {
        set result $value
        return 1
    }

    # now look for valueless names
    # I should strip out name=value pairs, so we don't end up with "name"
    # inside the "value" part of some other key word - some day
	
    set bad \[^a-zA-Z\]+
    if {[regexp -nocase  "$bad$key$bad" -$param-]} {
	return 1
    } else {
	return 0
    }
}

proc Html_ValueList {arrayName} {
    upvar $arrayName a
    set result <h2>$arrayName</h2>\n
    foreach {name value} [array get a] {
	append result "<dt>$name<dd>$a($name)\n"
    }
    append result </dl>\n
    return $result
}
