###
# Add hooks for bootstrap
###

package require httpd::doc	;# Httpd_Redirect Httpd_ReturnData

set PWD [file dirname [file normalize [info script]]]

Doc_AddRoot /bootstrap/css $PWD/css
Doc_AddRoot /bootstrap/fonts $PWD/fonts
Doc_AddRoot /bootstrap/js $PWD/js

package provide httpd::bootstrap 0.1