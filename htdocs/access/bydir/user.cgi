#!/usr/local/bin/tclsh8.0

# This script decodes the HTTP_AUTHORIZATION environment variable.

# When running as a cgi script, uncomment out the next line
#puts "Content-Type: text/html\n"

# Base64 decoding map
set i 0
foreach char {A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
	      a b c d e f g h i j k l m n o p q r s t u v w x y z \
	      0 1 2 3 4 5 6 7 8 9 + /} {
    set base64($char) $i
    set base64_en($i) $char
    incr i
}
proc Base64_Decode {string} {
    global base64

    set output {}
    set group 0
    set j 18
    foreach char [split $string {}] {
	if [string compare $char "="] {
	    set bits $base64($char)
	    set group [expr {$group | ($bits << $j)}]
	}

	if {[incr j -6] < 0} {
		scan [format %06x $group]] %2x%2x%2x a b c
		append output [format %c%c%c $a $b $c]
		set group 0
		set j 18
	}
    }
    return $output
}

# Here it is.  The authorization is a type followed by data:

if ![info exists env(HTTP_AUTHORIZATION)] {
    puts "(no user)"
    exit 0
}

set parts [split $env(HTTP_AUTHORIZATION)]
set type [lindex $parts 0]		;# Should be "Basic"
set code [lindex $parts 1]

# For basic authentication, the code is base64 encoded user:password

set parts [split [Base64_Decode $code] :]
set user [lindex $parts 0]
set pass [lindex $parts 1]

puts $user
exit 0
