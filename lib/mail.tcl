# mail.tcl
# Crude mail support that only works on systems with /usr/lib/sendmail
#
# The /mail URL is registered as a direct url that maps to procedures
# in this file that begin with Mail.
#
# Brent Welch (c) 1997 Sun Microsystems
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# SCCS: @(#) mail.tcl 1.1 97/06/26 15:11:35

package provide mail 1.0

proc Mail_Url {dir} {
    Direct_Url $dir Mail
}

proc Mail/bugreport {email errorInfo args} {
    global Httpd
    MailInner $email "$Httpd(server) error" "" text/html "<pre>[protect_text $errorInfo]</pre>"
}

# If your form action is /mail/forminfo, then this procedure
# sends the results to the address specified by "sendto"
proc Mail/forminfo {sendto subject args} {
    set from ""
    foreach {name value} $args {
	append message [list Data $name $value]\n
	if {[string compare $name "email"] == 0} {
	    set from $value
	}
    }
    MailInner $sendto $subject $from text/plain $message
}

# Older version of mail/forminfo
proc Mail/formdata {email subject args} {
    foreach {name value} $args {
	append message "$name: $value\n"
    }
    MailInner $email $subject {} text/plain $message
}

proc MailInner {sendto subject from type body} {
    global tcl_platform
    set headers  \
"To: $sendto
Subject: $subject
Mime-Version: 1.0
Content-Type: $type"
    if {[string length $from]} {
	append headers "\nFrom: $from"
    }

    set message "$headers\n\n$body"

    switch $tcl_platform(platform) {
	unix {
	    if [catch {
		exec /usr/lib/sendmail $sendto << $message
	    } err] {
		Stderr "ERROR: $err"
		Stderr $message
	    } else {
		return "Mailed report to <b>$sendto</b>"
	    }
	}
	default	{
	    Stderr $message
	}
    }
    return "Unable to send mail"
}
