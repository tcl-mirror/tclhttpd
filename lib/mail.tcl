# mail.tcl
# Crude mail support that only works on systems with /usr/lib/sendmail
#
# The /mail URL is registered as a direct url that maps to procedures
# in this file that begin with Mail.
#
# Brent Welch (c) 1997 Sun Microsystems
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: mail.tcl,v 1.11 2000/08/02 07:06:53 welch Exp $

package provide httpd::mail 1.0

foreach f {/usr/lib/sendmail /usr/sbin/sendmail} {
    if {[file exists $f]} {
	set Mail(program) $f
	break
    }
}

proc Mail_Url {dir} {
    Direct_Url $dir Mail
}

proc Mail/bugreport {email errorInfo args} {
    global Httpd
    set html "<pre>"
    foreach {name value} $args {
	if {([string compare $name "env"] == 0) && 
		([catch {array set X $value}] == 0)} {
	    # add this later
	    continue
	} else {
	    append html "$name: $value\n"
	}
    }
    append html  $Httpd(server)\n
    append html [protect_text $errorInfo]

    if {[info exist X]} {
	append html "\n\nEnvironment:\n"
	foreach n [lsort [array names X]] {
	    append html "  $n: $X($n)\n"
	}
    }
    append html "</pre>"

    MailInner $email "$Httpd(name):$Httpd(port) error" "" text/html $html
}

# If your form action is /mail/forminfo, then this procedure
# sends the results to the address specified by "sendto"
proc Mail/forminfo {sendto subject href label args} {
    set from ""
    foreach {name value} $args {
	# If the value has unbalanced braces, we will do base64
	# encoding to avoid a huge jumble of backslashes and
	# a long line that will not survive the email transport
	set blob [list $value]
	if {[regsub -all \\\\ $blob {} _] > 0} {
	    append message "[list Data64 $name] \\\n"
	    append message [list [base64::encode $value]]\n
	} else {
	    append message [list Data $name $value]\n
	}
	if {[string compare $name "email"] == 0} {
	    set from $value
	}
    }
    set html [MailInner $sendto $subject $from text/plain $message]
    if {[string length $href]} {
	if {[string length $label] == 0} {
	    set label Back
	}
	append html "<p><a href=\"$href\">$label</a>"
    }
    return $html
}

# This form is designed to be embedded into a page
# that handles form data.

proc Mail_FormInfo {} {
    global page
    set html {<!-- Mail_FormInfo -->}
    if {[info exist page(query)]} {
	array set q $page(query)
	if {[info exist q(sendto)] && [info exist q(subject)]} {
	    eval {Mail/forminfo $q(sendto) $q(subject) {} {}} $page(query)
	    set html {<!-- Mail_FormInfo sent email -->}
	}
    }
    return $html
}

# Older version of mail/forminfo
proc Mail/formdata {email subject args} {
    foreach {name value} $args {
	append message "$name: $value\n"
    }
    MailInner $email $subject {} text/plain $message
}

proc MailInner {sendto subject from type body} {
    global tcl_platform Mail
    set headers  \
"To: $sendto
Subject: $subject
Mime-Version: 1.0
Content-Type: $type"
    if {[string length $from]} {
	append headers "\nFrom: $from"
    }

    set message "$headers\n\n$body"

    if {[info exists Mail(program)]} {
	if {[catch {
	    exec $Mail(program) $sendto << $message
	} err]} {
	    Log "" MailError $err
	} else {
	    return "<font size=+1><b>Thank You!</font></b><p>Mailed report to <b>$sendto</b>"
	}
    } else {
	Log "" NoMailProgram
	return "Unable to send mail"
    }
}

