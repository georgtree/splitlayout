package require tcltest
namespace import ::tcltest::*
package require Tcl 9.0-
package require splitlayout
set currentDir [file normalize [file dirname [info script]]]
configure {*}$argv -testdir $currentDir
runAllTests
