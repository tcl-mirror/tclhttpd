# URL-based administration

package provide admin 1.0

proc Admin_Url {dir} {
    Direct_Url $dir Admin
    catch {Admin/redirect/reload}	;# Load redirects
}

proc Admin/redirect/reload {} {
    global Doc
    set path [file join $Doc(root) redirect]
    if { ! [file exists $path]} {
	return
    }
    source $path
    set html "<h3>Reloaded redirect file</h3>"
    set in [open $path]
    append html "<table><tr><td>OLD</td><td>NEW</td></tr>"
    while {[gets $in line] >= 0} {
	if {[regexp ^Url_Redirect $line]} {
	    append html <tr>
	    foreach item [lrange $line 1 2] {
		append html "<td>$item</td>"
	    }
	    append html </tr>
	}
    }
    append html </table>
    close $in
    return $html
}
proc Admin/redirect {old new} {
    global Doc Httpd
    if {[string length $old] == 0} {
	return "<h1>Redirect URL</h1>\n\
		<form action=redirect method=post>\n\
		OLD: <input type=input name=old><br>\n\
		NEW: <input type=input name=new><br>\n\
		<input type=submit value=\"Redirect URL\"></form>"
    }
    if {[string length $new] == 0} {
	return "<h1>Redirect URL</h1>\n\
		<form action=redirect method=post>\n\
		<input type=hidden name=old value=$old>\n\
		OLD: $old<br>\n\
		NEW: <input type=input name=new><br>\n\
		<input type=submit value=\"Redirect URL\"></form>"
    }
    set server $Httpd(name)
    if {$Httpd(port) != 80} {
	append server :$Httpd(port)
    }
    if ![regexp ^http: $new] {
	set new http://$server$new
    }

    ####
    # Need password protection for this page
    ####

    return "<h1>Redirect Form Disabled</h1>\n\
	   Url_Redirect $old http:$server$new"

    Url_Redirect $old $new
    if [info exists Doc(notfound,$old)] {
	unset Doc(notfound,$old)
    }
    return <h1>ok</h1>
}

