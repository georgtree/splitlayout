package require ruff
package require fileutil
package require splitlayout

set docDir [file dirname [file normalize [info script]]]
set sourceDir [file join $docDir ..]
source [file join $docDir tableHelpers.tcl]
source [file join $docDir startPage.ruff]

set packageVersion [package versions splitlayout]
puts $packageVersion
set title "splitlayout package"

set preparedStartPage [::splitlayoutDoc::TablesForRuff $startPage]
set startPageNroff $preparedStartPage

set commonSphinx [list -title $title -sortnamespaces false -preamble $startPage -pagesplit namespace -recurse false\
                    -includesource false -pagesplit namespace -autopunctuate true -compact false -includeprivate false\
                    -product splitlayout -diagrammer "ditaa --round-corners" -version $packageVersion\
                    -copyright "George Yashin" {*}$::argv]
set commonNroff [list -title $title -sortnamespaces false -preamble $startPageNroff -pagesplit namespace -recurse false\
                         -pagesplit namespace -autopunctuate true -compact false -includeprivate false\
                         -product splitlayout -diagrammer "ditaa --round-corners" -version $packageVersion\
                         -copyright "George Yashin" {*}$::argv]

set namespaces [list ::splitlayout]
set namespacesNroff $namespaces

set savedPreambles {}
try {
    set savedPreambles [::splitlayoutDoc::PreparePreambles $namespaces]
    ruff::document $namespaces -format sphinx -outfile splitlayout.rst -outdir [file join $docDir sphinx]\
            {*}$commonSphinx
    ruff::document $namespacesNroff -format nroff -outdir $docDir -outfile splitlayout.n {*}$commonNroff
} finally {
    ::splitlayoutDoc::RestorePreambles $savedPreambles
}

# Ruff emits diagram SVGs next to its generated RST. Keep the published files in
# _static/assets and point the figure directives at that same copy.
set sphinxDir [file join $docDir sphinx]
set assetDir [file join $docDir _static assets]
set diagramRefs {}
foreach diagram [glob -nocomplain -directory [file join $sphinxDir assets] *.svg] {
    set name [file tail $diagram]
    file mkdir $assetDir
    set fonts [list {font-family='Courier'} {font-family='Fira Code, Consolas, monospace'}]
    ::fileutil::updateInPlace $diagram [list string map $fonts]
    file rename -force $diagram [file join $assetDir $name]
    lappend diagramRefs ".. figure:: assets/$name\n" ".. figure:: ../_static/assets/$name\n"
}
if {[llength $diagramRefs]} {
    foreach rst [glob -directory $sphinxDir *.rst] {
        ::fileutil::updateInPlace $rst [list string map $diagramRefs]
    }
}

::fileutil::appendToFile [file join $sphinxDir conf.py] {
extensions = list(dict.fromkeys(globals().get("extensions", []) + [
    "sphinx_rtd_theme",
    "sphinx.ext.githubpages",
]))
suppress_warnings = [
    "image.not_readable",
]
html_theme = "sphinx_rtd_theme"
html_theme_options = {
    "collapse_navigation": False,
    "sticky_navigation": True,
    "navigation_depth": 4,
    "includehidden": True,
    "titles_only": False,
}
# manual.css is maintained directly in the published _static directory.
# Do not ask Sphinx to copy that directory onto itself.
html_static_path = []
html_css_files = list(globals().get("html_css_files", [])) + ["manual.css"]
from docutils import nodes
from sphinx.util.osutil import relative_uri
from pygments.lexers.tcl import TclLexer
from pygments.token import Operator

class MyTclLexer(TclLexer):
    def get_tokens_unprocessed(self, text):
        for i, t, v in super().get_tokens_unprocessed(text):
            if v == "=":
                yield i, Operator, v   # or Name.Builtin
            elif v == "$":
                yield i, Operator, v   # or Name.Builtin
            elif v == "\\":
                yield i, Operator, v   # or Name.Builtin
            elif v == "%":
                yield i, Operator, v   # or Name.Builtin
            elif v == "'":
                yield i, Operator, v   # or Name.Builtin
            else:
                yield i, t, v

def link_static_figures(app, doctree, docname):
    if app.builder.name != "html":
        return
    for image in doctree.findall(nodes.image):
        uri = image["uri"]
        if uri.startswith("../_static/assets/"):
            target = relative_uri(app.builder.get_target_uri(docname), uri[3:])
            image["uri"] = target
            # The SVG already lives at its published URL. Skip Sphinx's image copy.
            image["candidates"] = {"?": target}

def setup(app):
    app.connect("doctree-resolved", link_static_figures)
    from sphinx.highlighting import lexers
    lexers["tcl"] = MyTclLexer()
}

# Use one Python environment for Sphinx and the RTD theme; propagate failures.
set python python
if {[info exists ::env(DOC_PYTHON)] && $::env(DOC_PYTHON) ne {}} {
    set python $::env(DOC_PYTHON)
}
if {![file readable [file join $docDir _static manual.css]]} {
    error "missing documentation stylesheet: [file join $docDir _static manual.css]"
}
exec -- $python -m sphinx -E -a -b html [file join $docDir sphinx] $docDir >@stdout 2>@stderr

# nroff pages names processing
foreach file [glob -directory $docDir *.n] {
    set old $file
    set tmp [file join $docDir __temp_rename__.n]
    set new [file join $docDir [string tolower [file tail $file]]]
    if {$old eq $new} {continue}
    file rename -force $old $tmp
    file rename -force $tmp $new
}

set specialPages [list]

foreach namespacePath $namespacesNroff {
    set tails [list]
    while {$namespacePath ne {}} {
        set tail [string tolower [namespace tail $namespacePath]]
        regsub -all {\s+} [string trim $tail] {-} tail
        set namespacePath [namespace qualifiers $namespacePath]
        lappend tails $tail
    }
    lappend tails [string tolower splitlayout]
    set manFileName [join [lreverse $tails] -]
    if {$manFileName ni $specialPages} {
        lappend manFilesLinks "${manFileName}(n)"
    }
}

set linksString ".SH SEE ALSO
splitlayout(n) - package's main page
.br
.sp 1
Public commands and classes documentation:
.br
[join $manFilesLinks \n.br\n]"

proc addLinks2man {fileContents} {
    global linksString
    append fileContents "\n$linksString"
    return $fileContents
}

foreach file [glob -directory $docDir *.n] {
    fileutil::updateInPlace $file addLinks2man
}
