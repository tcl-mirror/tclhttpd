#!/bin/sh
# htpass.tcl
# Crude interface to generate encrypted passwords for htaccess files
#
# \
exec expect "$0" ${1+"$@"}

load /home/welch/cvs/tclhttpd/lib/Binaries/SunOS/5.6/crypt.so


stty -echo
send_user "Enter a word to crypt: "
expect_user {
    -re "(\[^\n]+)\n" { set pass1 $expect_out(1,string) ; send_user \r\n}
    timeout { send_user timeout\n ; exit 1}
}

send_user "Again, please: "
expect_user {
    -re "(\[^\n]+)\n" { set pass2 $expect_out(1,string) ; send_user \r\n}
    timeout { send_user timeout\n ; exit 1}
}
stty echo

if {[string compare $pass1 $pass2]} {
    send_user "Words do not match\n"
    exit 1
}
if {[string length $pass1] < 1} {
    send_user "No empty words, please\n"
    exit 1
}

set salt ""
append salt [format %c [expr 65+int(rand()*26)]]
append salt [format %c [expr 97+int(rand()*26)]]
set newpass [crypt $pass1 $salt]

send_user $newpass\n
exit 0
