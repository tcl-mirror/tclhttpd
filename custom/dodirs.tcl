# code to start tclhttpd modules contained in subdirs of custom/

set oldpwd [pwd]

foreach dir [glob -nocomplain [file join [file normalize $Config(library)] *]] {
    if {[file isdirectory $dir]} {
	cd $dir
	if {$Config(debug)} {
	    Stderr "Loading code from module $dir"
	}
	if {[catch {source [file join $dir startup.tcl]} err]} {
	    Stderr "$dir: $err"
	} elseif {$Config(debug)} {
	    Stderr "Loaded [file tail $dir]: $err"
	}
    }
}

cd $oldpwd
