#!/bin/sh
# \
exec tclsh8.0 "$0" ${1+"$@"}

source [file join [file dirname [info script]] cgilib.tcl]

Cgi_Header Hello
flush stdout

set query [Cgi_List]

H1 "Hello, World!"
puts "<table border=1>"
foreach {name value} $query {
    puts "<tr><td>$name</td><td>$value</td></tr>"
}
puts </table>
H2 [clock format [clock seconds]]

H3 Environment
puts "<table border=1>"
foreach {name value} [array get env] {
    puts "<tr><td>$name</td><td>$value</td></tr>"
}
puts </table>
flush stdout
exit 0
