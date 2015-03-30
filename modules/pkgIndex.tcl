set PWD $dir
foreach subpath [glob -nocomplain $PWD/*] {
  if {[file exists $subpath/pkgIndex.tcl]} {
    set dir $subpath
    source $subpath/pkgIndex.tcl
  }
}