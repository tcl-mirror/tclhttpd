###
# Utilities for automating the build process of C extensions
###
use codebale

# @synopsis:
#
# CTHULHU modules adds autobuild utilities
#

#::namespace eval ::cthulhu {}

###
# title: define which modules the source we are adding contributes to
###
proc cthulhu_config args {
  set ::cthulhu_config [dict merge $::cthulhu_config $args]
}

###
# topic: 9c0c2d73c1afa8ef83a739c5d01309d0
# title: Signal for a C header to be read with mkhdr
###
proc cthulhu_add_cheader {filename {trace 0}} {
  set hfilename [::cygrelative $::project(srcdir) $filename]
  if {$hfilename in $::project(headers_verbatim)} {
    return
  }
  if {$hfilename ni $::project(headers)} {
    lappend ::project(headers) $hfilename
    #::cthulhu_read_csourcefile $file
  }
}

###
# topic: c52ea7e1ff44f11f960d99a55e4ab998
# title: Add the contents of a header file verbatim to the internal headers and public headers
###
proc cthulhu_add_cheader_verbatim {filename {trace 0}} {
  set hfilename [::cygrelative $::project(srcdir) $filename]
  ldelete ::project(headers) $hfilename
  if {$hfilename ni $::project(headers_verbatim)} {
    lappend ::project(headers_verbatim) $hfilename
  }
}

###
# topic: 91e4d7da8dd82d78af41561360deab10
# title: Signal for a C source to be read with mkhdr
###
proc cthulhu_add_csource {filename {cmdconfig {}}} {
  set config [dict merge $::cthulhu_config $cmdconfig]
  
  set cfilename [::cygrelative $::project(srcdir) $filename]
  dict set ::thesources $cfilename $config
  if {$cfilename ni $::project(sources)} {
    lappend ::project(sources) $cfilename
  }
  if {[string is true [dictGetnull $config scan]]} {
    if {$cfilename ni $::project(scanlist)} {
      lappend ::project(scanlist) $cfilename
    }
  }
}

###
# topic: f11da5f705442524715e8f8fe9af5276
# title: Add a path containing C code
###
proc cthulhu_add_directory {here {cmdconfig {}}} {
  set config [dict merge {
    cthulhu-ignore-hfiles {}
    cthulhu-ignore-cfiles {}
    build-ignore-cfiles {}
    cthulhu-trace-cfiles {}
  } $::cthulhu_config $cmdconfig]

  dict with config {}
  
  set here [::realpath $here]
  ###
  # Execute any .tcl scripts in the generic directory
  ###
  foreach file [lsort  [glob -nocomplain [file join $here *.tcl]]] {
    if {[file tail $file] eq "pkgIndex.tcl"} continue
    cd $here
    uplevel #0 [list source $file]
  }
  ###
  # Build a list of all public header files that
  # need to be amalgamated into the publicly exported
  # version
  ###
  foreach file [lsort  [glob -nocomplain [file join $here *.h]]] {
    cthulhu_include_directory $here
    set fname [file tail $file]
    if {${cthulhu-ignore-hfiles} eq "*"} continue
    if { $fname in ${cthulhu-ignore-hfiles} } continue
    if {[string match *_cases.h $fname]} continue
    cthulhu_add_cheader $file
  }
  foreach file [lsort  [glob -nocomplain [file join $here *.c]]] {
    if {[file tail $file] in ${build-ignore-cfiles} } continue
    cthulhu_add_csource $file
  }
}

proc cthulhu_include_directory {here} {
   if { $here ni $::project(include_paths) } {
      lappend ::project(include_paths) $here
    }
}

###
# topic: 1d3a911fd58337df92205759a6d092c3
# title: Add a source file in Tcl that produces a C file
###
proc cthulhu_add_dynamic {csource tclscript} {
  set cfilename [::cygrelative $::project(srcdir) $csource]
  set tclfilename [::cygrelative $::project(srcdir) $tclscript]
  dict set ::thesources $cfilename tclscript $tclfilename
}

###
# topic: d10665e8da4dd0781bb0a9ced5486e40
# title: Add a pure-tcl library
###
proc cthulhu_add_library {here {cmdconfig {}}} {
  set config [dict merge {
    cthulhu-ignore-tclfiles {}
  } $::cthulhu_config $cmdconfig]

  dict with config {}
  set here [::realpath $here]
  foreach file [lsort [glob -nocomplain $here/*.tcl]] {
    if {[file tail $file] in ${cthulhu-ignore-tclfiles}} continue
    set libfilename [::cygrelative $::project(srcdir) $libfilename]
  }
}

###
# topic: ccfe65b26705afc498e08d3004031066
# title: Detect where we need to produce a _cases.h file to automate a C source
###
proc cthulhu_detect_cases filename {
  set cfilename [::cygrelative $::project(srcdir) $filename]
  set cases [codebale_detect_cases $filename]
  if {![llength $cases]} return
  set dirname [file dirname $cfilename]
  foreach case $cases {
    lappend result [file join $dirname $case]
  }
  dict set ::thesources $cfilename cases $result
}

###
# topic: 41d95037e5a1cab76939150efdef8939
# title: Declare an end to modifications of ::project
# description:
#    This directive is placed after the last set ::project(X) Y
#    but before the first ::cthulhu_add_*
###
proc cthulhu_init args {
  set ::cthulhu_config [dict merge {
    target pkg
  } $args]
  set ::project(strlen) [string length $::project(path)/]
  set ::project(cases)  {}
  set ::project(sources)  {}
  set ::project(headers)  {}
  set ::project(scanlist) {}
  set ::project(headers_verbatim) {}
}

###
# topic: 17c9931c3ec5ba115efafaaaa3cf61ed
###
proc cthulhu_mk_lib_init.c outfile {
  global project cout
  set cout      [open $outfile w]
  fconfigure $cout -translation crlf
  puts $cout $::project(standard_header)
  puts $cout "#include \"$::project(h_file_int)\""
  
  puts $cout "
  
  extern int DLLEXPORT ${project(init_funct)}( Tcl_Interp *interp ) \{
    Tcl_Namespace *modPtr\;
  "
  puts $cout {
      /* Initialise the stubs tables. */
  #ifdef USE_TCL_STUBS
      if (
          !Tcl_InitStubs(interp, "8.3", 0)
      ) {
          return TCL_ERROR;
      }
  #endif
  }

  foreach module $::project(modules) {
    puts $cout "  if(${module}(interp)) return TCL_ERROR\;"
  }
  foreach {nspace cmds} [lsort -stride 2 -dictionary [array get namespace_commands]] {
    puts $cout "
    modPtr=Tcl_FindNamespace(interp,\"$nspace\",NULL,TCL_NAMESPACE_ONLY)\;
    if(!modPtr) {
      modPtr = Tcl_CreateNamespace(interp, \"$nspace\", NULL, NULL);
    }
    "
    foreach {command cfunct} [lsort -stride 2 -dictionary $cmds] {
      puts $cout "  Tcl_CreateObjCommand(interp,\"::${nspace}::${command}\",(Tcl_ObjCmdProc *)$cfunct,NULL,NULL);"
    }
    puts $cout {
    Tcl_CreateEnsemble(interp, modPtr->fullName, modPtr, TCL_ENSEMBLE_PREFIX);
    Tcl_Export(interp, modPtr, "[a-z]*", 1);
    }
  }
  
  puts $cout {
      /* Register the package. */}
  puts $cout "    if (Tcl_PkgProvide(interp, \"${project(pkgname)}\", \"${project(pkgvers)}\")) return TCL_ERROR\;"
  
  
  puts $cout "  return TCL_OK\;\n\}"
  close $cout
}

###
# topic: 17c9931c3ec5ba115efafaaaa3cf61ed
###
proc cthulhu_mk_app_init.c outfile {
  global project cout
  set cout      [open $outfile w]
  fconfigure $cout -translation crlf
  puts $cout $::project(standard_header)
  puts $cout "#include \"$::project(h_file_int)\""
  
  puts $cout "
  
  int ${project(init_funct)}_static( Tcl_Interp *interp ) \{
    Tcl_Namespace *modPtr\;
  "

  foreach module $::project(modules) {
    puts $cout "
  if(${module}(interp)) \{
    return TCL_ERROR\;
  \}
  "
  }
  foreach {nspace cmds} [lsort -stride 2 -dictionary [array get namespace_commands]] {
    puts $cout "
    modPtr=Tcl_FindNamespace(interp,\"$nspace\",NULL,TCL_NAMESPACE_ONLY)\;
    if(!modPtr) {
      modPtr = Tcl_CreateNamespace(interp, \"$nspace\", NULL, NULL);
    }
    "
    foreach {command cfunct} [lsort -stride 2 -dictionary $cmds] {
      puts $cout "  Tcl_CreateObjCommand(interp,\"::${nspace}::${command}\",(Tcl_ObjCmdProc *)$cfunct,NULL,NULL);"
    }
    puts $cout {
    Tcl_CreateEnsemble(interp, modPtr->fullName, modPtr, TCL_ENSEMBLE_PREFIX);
    Tcl_Export(interp, modPtr, "[a-z]*", 1);
    }
  }
  
  puts $cout {
      /* Register the package. */}
  puts $cout "    if (Tcl_PkgProvide(interp, \"${project(pkgname)}\", \"${project(pkgvers)}\")) return TCL_ERROR\;"
  
  
  puts $cout "  return TCL_OK\;\n\}"
  close $cout
}

###
# topic: 06bca7e2bddebdca69537fc3a9a0735f
###
proc cthulhu_mk_sources {bldpath outfile} {
  global project
  file mkdir $bldpath
  set fout [open $outfile w]
  fconfigure $fout -translation crlf
  set pkg_sources {}
  set pkg_objects {}
  foreach {csource} $::project(sources) {
    set ofile [file join $bldpath [string trimleft [string map {/ _ .c .o .. {}} $csource] _]]
    lappend pkg_sources $csource
    lappend pkg_objects $ofile
    dict set ::thesources $csource ofile $ofile
  }
  set ILINE "MYINCLUDES="
  foreach ipath $::project(include_paths) {
    append ILINE \\\n"  -I[::cygrelative $::project(srcdir) $ipath]"
  }
  puts $fout $ILINE
  puts $fout {}
  define PKG_OBJECTS [lsort  $pkg_objects]
  define PKG_SOURCES [lsort  $pkg_sources]
  
  #puts $fout "build/$project(c_file):"
  #puts $fout "\t\${TCLSH} scripts/cthulhu.tcl\n"
  
  foreach {csource cinfo} $::thesources {
    if {[dict exists $cinfo ofile]} {
      set ofile [dict get $cinfo ofile]
    } else {
      set ofile {}
    }
    set hfiles {}
    if {[dict exists $cinfo cases]} {
      foreach hfile [dict get $cinfo cases] {
        puts $fout "$hfile:"
        puts $fout "\t\$(TCLSH_PROG) scripts/mktclopts.tcl $csource\n"
        lappend hfiles $hfile
      }
    }
    if {[dict exists $cinfo tclscript]} {
      puts $fout "$csource:"
      puts $fout "\t\$(TCLSH_PROG) [dict get $cinfo tclscript] $csource\n"
      if {$ofile != {}} {
        puts $fout "$ofile: $hfiles"
        puts $fout "\t\$(COMPILE) [dictGetnull $cinfo extra] \$(MYINCLUDES) -c $csource -o \$@\n"
      }
    } else {
      if {$ofile != {}} {
        puts $fout "$ofile: $hfiles"
        puts $fout "\t\$(COMPILE) [dictGetnull $cinfo extra] \$(MYINCLUDES) -c $csource -o \$@\n"
      }
    }
  }
  close $fout
}

###
# topic: f7eec240dada25d73c1f68a877fa40be
# title: Produce the PROJECT.decls file
# description: Tools for automating the process of building stubs libraries
###
proc cthulhu_mk_stub_decls {pkgname mkhdrfile path} {
  set outfile [file join $path/$pkgname.decls]
  
  ###
  # Build the decls file
  ###
  set fout [open $outfile w]
  puts $fout [subst {###
  # $outfile
  #
  # This file was generated by [info script]
  ###
  
  library $pkgname
  interface $pkgname
  }]
  
  set fin [open $mkhdrfile r]
  set thisline {}
  set functcount 0
  while {[gets $fin line]>=0} {
    append thisline \n $line
    if {![info complete $thisline]} continue
    set readline $thisline
    set thisline {}
    set type [lindex $readline 1]
    if { $type ne "f" } continue
  
    set infodict [lindex $readline end]
    if {![dict exists $infodict definition]} continue
    set def [dict get $infodict definition]
    set def [string trim $def]
    set def [string trimright $def \;]
    if {![string match "*STUB_EXPORT*" $def]} continue
    puts $fout [list declare [incr functcount] $def]
    
  }
  close $fin
  close $fout
  
  ###
  # Build [package]Decls.h
  ###
  set hout [open [file join $path ${pkgname}Decls.h] w]
  
  close $hout

  set cout [open [file join $path ${pkgname}StubInit.c] w]
puts $cout [string map [list %pkgname% $pkgname %PkgName% [string totitle $pkgname]] {
#ifndef USE_TCL_STUBS
#define USE_TCL_STUBS
#endif
#undef USE_TCL_STUB_PROCS

#include "tcl.h"
#include "%pkgname%.h"

 /*
 ** Ensure that Tdom_InitStubs is built as an exported symbol.  The other stub
 ** functions should be built as non-exported symbols.
 */

#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT

%PkgName%Stubs *%pkgname%StubsPtr;

 /*
 **----------------------------------------------------------------------
 **
 **  %PkgName%_InitStubs --
 **
 **        Checks that the correct version of %PkgName% is loaded and that it
 **        supports stubs. It then initialises the stub table pointers.
 **
 **  Results:
 **        The actual version of %PkgName% that satisfies the request, or
 **        NULL to indicate that an error occurred.
 **
 **  Side effects:
 **        Sets the stub table pointers.
 **
 **----------------------------------------------------------------------
 */

char *
%PkgName%_InitStubs (Tcl_Interp *interp, char *version, int exact)
{
  char *actualVersion;
  
  actualVersion = Tcl_PkgRequireEx(interp, "%pkgname%", version, exact,
                                                                   (ClientData *) &%pkgname%StubsPtr);
  if (!actualVersion) {
        return NULL;
  }
  
  if (!%pkgname%StubsPtr) {
        Tcl_SetResult(interp,
                                  "This implementation of %PkgName% does not support stubs",
                                  TCL_STATIC);
        return NULL;
  }
  
  return actualVersion;
}
}]
  close $cout
}

###
# topic: ba1d2c7e8eab96029e434d54f917ef5a
###
proc cthulhu_mkhdr_index {hout docfileout} {
  global project
  set scanlist {}
  foreach file $::project(headers) {
    lappend scanlist [::realpath [file join $::project(srcdir) $file]]
  }
  foreach file $::project(scanlist) {
    lappend scanlist [::realpath [file join $::project(srcdir) $file]]
  }
  ldelete scanlist  [::realpath $::project(srcdir)/generic/$::project(h_file_int)]
  ldelete scanlist  [::realpath $::project(srcdir)/generic/$::project(c_file)]
  puts "WRITING INTERNAL HEADERS TO $hout"
  set fout [open $hout w]
puts $fout "/*
** DO NOT EDIT THIS FILE
** It is automagically generated by scripts/cthulhu.tcl
*/"
  fconfigure $fout -translation crlf
  foreach file $::project(headers_verbatim) {
    puts $fout "/* Verbatim headers */"
    set fullname [file join $::project(srcdir) $file]
    set type [file type $fullname]
    if {$type ne "file"} continue
    puts $fout "/*\n *$file \n*/"
    set fin [open $fullname r]
    puts $fout [read $fin]
    close $fin
  }
  puts $fout "/* FUNCTION DECLARATIONS */"
  ###
  # Do get around platform line breaks, we output to a tmp file
  # and concat in Tcl
  ###
  set crscanlist {}
  foreach file $scanlist {
    set crfile $file.cr[file extension $file]
    set rawfin [open $file r]
    set rawfout [open $crfile w]
    fconfigure $rawfout -translation lf
    puts $rawfout [read $rawfin]
    close $rawfout
    close $rawfin
    lappend crscanlist $crfile
  }
  
  ::cthulhu_mkhdr -h -- {*}$crscanlist > $hout.cr
  set rawfin [open $hout.cr r]
  puts $fout [read $rawfin]
  close $rawfin
  file delete $hout.cr
  close $fout
  
  ::cthulhu_mkhdr -doc -- {*}$scanlist > $docfileout
  
  foreach file $crscanlist {
    file delete $file
  }

  foreach {prefix cases} $::project(cases) {
    ::codebale_cases_generate $prefix $cases
  }

  set fin [open $hout r]
  while {[gets $fin line]>=0} {
    if {[regexp TCL_MODULE $line] || [regexp DLLEXPORT $line]} {
      foreach regexp {
           {(.*) ([a-zA-Z_][a-zA-Z0-9_]*) *\((.*)\)}
           {(.*) (\x2a[a-zA-Z_][a-zA-Z0-9_]*) *\((.*)\)}
      } {
        if {[regexp $regexp $line all keywords funcname arglist]} {
          lappend ::project(modules) $funcname        
          break
        }
      }
    }
  }
}

proc cthulhu_find_mkhdr {} {
  set exename [lindex [find-an-executable mkhdr] 0]
  if {$exename ne {}} {
    return [list exec [::realpath $exename]]
  }
  if {[info exists ::odie(mkhdr)]} {
    if {[file exists [::realpath $::odie(mkhdr)]]} {
      return [list exec [::realpath $::odie(mkhdr)]]
    } 
  }
  doexec $::odie(cc) -o mkhdr.o -c $::odie(src_dir)/scripts/mkhdr.c
  doexec $::odie(cc) mkhdr.o -o mkhdr$::odie(exe_suffix)
  file copy -force mkhdr$::odie(exe_suffix) [::realpath $::odie(mkhdr)]
  return [list exec [::realpath $::odie(mkhdr)]]
  error {mkhdr not available}
}


proc cthulhu_mkhdr args {
  set cmd [cthulhu_find_mkhdr]
  {*}${cmd} {*}$args
}

array set ::project {
  include_paths {}
  sources {}
  tcl_sources {}
  modules {}
}

