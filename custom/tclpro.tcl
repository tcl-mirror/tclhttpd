
# Merge in TclPro docs, if present

set htdocs_2 [file join $Config(docRoot) ../../doc/html]
if {[file isdirectory $htdocs_2]} {
    Doc_AddRoot /tclpro	$htdocs_2
}

