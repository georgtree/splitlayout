# Package and install the script-only distribution for NMAKE.
proc readFile {path} {
    set f [open $path]
    try {read $f} finally {close $f}
}

proc installFile {src dst} {
    puts " Install $src $dst"
    file mkdir [file dirname $dst]
    file copy -force $src $dst
}

proc addFiles {filesVar src dst} {
    upvar 1 $filesVar files
    if {[file isdirectory $src]} {
        foreach child [glob -nocomplain -directory $src *] {
            addFiles files $child [file join $dst [file tail $child]]
        }
    } else {
        dict set files $src $dst
    }
}

lassign $argv target out prefix
set root [file dirname [file dirname [file normalize [info script]]]]
if {![regexp {AC_INIT\(\[splitlayout\],\[([0-9.]+)\]\)} [readFile [file join $root configure.ac]] -> version]} {
    error "Cannot read the splitlayout version from configure.ac"
}
set package splitlayout$version
if {$target eq "build"} {
    file mkdir $out
    file copy -force [file join $root splitlayout.tcl] $out
    set f [open [file join $out pkgIndex.tcl] w]
    try {
        puts -nonewline $f [string map [list @PACKAGE_NAME@ splitlayout @PACKAGE_VERSION@ $version] \
                [readFile [file join $root pkgIndex.tcl.in]]]
    } finally {close $f}
    exit
}
if {$target eq "dist-zip"} {
    set archive [file normalize [file join $prefix $package.zip]]
    set prefix [file join $prefix $package]
    file delete -force $prefix
}
set lib [file join $prefix lib $package]
set doc [file join $prefix share $package doc]
set man [file join $prefix share man mann]
set files {}
foreach f {splitlayout.tcl pkgIndex.tcl} {
    dict set files [file join $out $f] [file join $lib $f]
}
dict set files [file join $root LICENSE.txt] [file join $doc LICENSE.txt]
foreach f [glob -directory [file join $root docs] -nocomplain *.n] {
    dict set files $f [file join $man [file tail $f]]
}
foreach f [glob -directory [file join $root docs] -nocomplain *.html objects.inv searchindex.js .nojekyll] {
    dict set files $f [file join $doc [file tail $f]]
}
foreach dir {_static assets images _images} {
    set src [file join $root docs $dir]
    if {[file isdirectory $src]} {addFiles files $src [file join $doc $dir]}
}
if {$target eq "uninstall"} {
    set dirs [list $lib $doc [file dirname $doc]]
    dict for {src dst} $files {
        file delete -force $dst
        set dir [file dirname $dst]
        while {[string first "$doc/" "$dir/"] == 0} {
            lappend dirs $dir
            set dir [file dirname $dir]
        }
    }
    foreach dir [lsort -unique -decreasing $dirs] {catch {file delete $dir}}
} else {
    dict for {src dst} $files {installFile $src $dst}
    if {$target eq "dist-zip"} {
        exec tar.exe -a -cf $archive -C $prefix .
        puts "Installation archive: $archive"
    }
}
