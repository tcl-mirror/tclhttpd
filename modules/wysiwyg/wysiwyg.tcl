###
# Add hooks for openWYSIWYG
###

package require httpd::doc	;# Httpd_Redirect Httpd_ReturnData

set PWD [file dirname [file normalize [info script]]]

Doc_AddRoot /wysiwyg/buttons $PWD/buttons
Doc_AddRoot /wysiwyg/css $PWD/css
Doc_AddRoot /wysiwyg/icons $PWD/icons
Doc_AddRoot /wysiwyg/js $PWD/js
Doc_AddRoot /wysiwyg/popups $PWD/popups

package provide httpd::wysiwyg 0.1