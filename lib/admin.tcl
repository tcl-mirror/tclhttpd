# URL-based administration

package provide admin 2.0

proc Admin_Url {dir} {
    Direct_Url $dir Admin
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

proc Admin/reset/counter {name} {
    
if {0} {
    # Ugh - get the socket handle in the DirectDomain procedure
    upvar 1 sock sock
  
    # Need a way to register administrator passwords
    # For now we just allow this to happen.

    if {![AuthVerifyBasic $sock $admin(authfile)]} {
	return "Password Check Failed"
    }
}
    Counter_Reset $name
    return "Reset Counter $name"
}
