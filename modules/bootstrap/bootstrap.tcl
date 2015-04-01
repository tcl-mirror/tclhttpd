###
# Add hooks for bootstrap
###

package require httpd::doc	;# Httpd_Redirect Httpd_ReturnData

set PWD [file dirname [file normalize [info script]]]

Doc_AddRoot /bootstrap $PWD

package provide httpd::bootstrap 0.1