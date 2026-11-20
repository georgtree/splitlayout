package require tcltest
namespace import ::tcltest::*
package require Tcl 9.0-
package require splitlayout
if {[info exists ::env(SPLITLAYOUT_TEST_TOOLTIP)] && $::env(SPLITLAYOUT_TEST_TOOLTIP)} {
    package require tooltip
}
set currentDir [file normalize [file dirname [info script]]]
configure {*}$argv -testdir $currentDir
exit [runAllTests]
