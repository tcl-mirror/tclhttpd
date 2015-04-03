###
# Add hooks for jshash
###

package require httpd::doc	;# Httpd_Redirect Httpd_ReturnData

set PWD [file dirname [file normalize [info script]]]

Doc_AddRoot /jshash $PWD/js

package provide httpd::jshash 0.1