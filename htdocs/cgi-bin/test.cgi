#!/bin/sh
# \
exec tclsh8.0 "$0" ${1+"$@"}

source [file join [file dirname [info script]] cgilib.tcl]

set query [Cgi_List]
Cgi_Header Hello

H1 "Hello, World!"
puts "<table border=1>"
foreach {name value} $query {
    puts "<tr><td>$name</td><td>$value</td></tr>"
}
puts </table>
H2 [clock format [clock seconds]]
exit 0
