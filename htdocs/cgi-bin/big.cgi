#!/bin/sh
# \
#exec /usr/local/bin/tclsh8.0 "$0" ${1+"$@"}
# \
exec /usr/local/bin/tclsh8.0 "$0" ${1+"$@"}

if {[info commands "unsupported0"] == "unsupported0"} {
    rename unsupported0 copychannel
}
if {[info commands "copychannel"] == ""} {
    proc copychannel {in out} {
	fcopy $in $out
    }
}

set path [file join [file dirname [file dirname [info script]]] images pwrdLogo200.gif]
set in [open $path]
#puts "Content-Type: text/plain"
#puts ""
puts "Content-Type: image/gif"
puts "Content-Length: [file size $path]"
puts ""
fconfigure $in -translation binary
fconfigure stdout -translation binary
copychannel $in stdout
close $in
exit 0
