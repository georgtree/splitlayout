# splitlayout — Dynamic pane layouts for Tcl/Tk

`splitlayout` is a pure Tcl megawidget for creating dynamically resizable layouts from nested `ttk::panedwindow`
widgets. Split a content area, add panes beside existing ones, remove subtrees, or exchange content between panes
without recreating the surviving application widgets.

## What it gives you (at a glance)

- Horizontal and vertical splits, combined at any nesting depth.
- Two or more panes in each split, with ordered insertion of new siblings.
- Retention of existing content when a leaf is split.
- Removal of individual panes or complete subtrees, with automatic collapse of redundant parent splits.
- Content swapping between leaves at different nesting levels.
- Leaf moves to edge or sibling destinations, preserving application widgets and state.
- Optional rectangular headers for mouse-driven swaps, edge moves, and insertion at sashes.
- Relative pane proportions and interactive sash resizing.
- Live resizing or deferred resizing with a configurable sash preview.
- Inspection of both the logical layout tree and the actual Tk widget hierarchy.
- Undocking owned content into native windows and docking it back without recreating widgets.

## General concept

A layout starts with one empty **leaf**. Each leaf owns a content frame into which the application places its widgets.
Splitting a leaf converts its node into a **split** and creates two new leaf nodes. A split owns a panedwindow and
has an ordered list of children. Each child can itself be a leaf or another split.

A split can contain more than two children. Use `insert` to add an empty leaf beside an existing child without
introducing another nesting level.

Layouts must be expressible through successive horizontal or vertical subdivisions. A pane can occupy the full
height or width beside a more deeply subdivided region, producing arrangements similar to row or column spans.
There are no grid coordinates or `-rowspan`/`-columnspan` options, and arbitrary overlapping grid arrangements are
not supported.

### Two hierarchies

The **logical tree** describes pane order, split orientation, and geometry relationships. The **Tk widget tree**
describes actual widget ownership and pathnames.

All managed content frames, optional leaf and split wrappers, and split panedwindows are immediate Tk children of the layout hull.
Grip canvases are children of their wrappers. Application widgets
are descendants of their content frame. Splitting, promoting, or swapping content changes its logical placement and
geometry container, while its actual Tk parent and widget pathnames stay the same.

Removing a content frame destroys that frame and its application widgets. Destroying the layout destroys all its
content, including floating windows. Surviving frames retain their widgets and state.

## Requirements

- Tcl and Tk 9.0 or newer.
- [argparse](https://github.com/georgtree/argparse), available to the selected Tcl interpreter.

## Installing

From the source directory, run:

```sh
./configure
make
make test
sudo make install
```

Use `make install` without `sudo` when installing into a user-writable prefix. On Windows, run the commands in an
MSYS2 shell with your Tcl/Tk installation available through the environment.

To select a Tcl installation and a custom installation prefix:

```sh
./configure \
    --with-tcl=/path/to/tcl/lib \
    --prefix=/your/prefix \
    --exec-prefix=/your/prefix
make
make test
make install
```

`--with-tcl` takes the directory containing `tclConfig.sh`. Use matching Tcl/Tk installations and make argparse
available to the selected interpreter. Tests require a graphical display.

Installation follows the configured prefix: the Tcl source and `pkgIndex.tcl` go together in
`lib/splitlayout0.4`. Load the installed package with:

```tcl
package require splitlayout 0.1
```

For a nonstandard prefix, add its library directory to Tcl's search path before loading the package:

```tcl
lappend auto_path /your/prefix/lib
package require splitlayout 0.1
```

Windows Tcl paths can use forward slashes. The same search-path mechanism can be used to locate argparse.

To stage an installation without writing into the configured system prefix:

```sh
make install DESTDIR=/path/to/staging
```

To uninstall, keep the configured build directory and use the same installation directory overrides:

```sh
sudo make uninstall
```

Omit `sudo` for a user-writable prefix. For a staged installation, use `make uninstall DESTDIR=/path/to/staging`.

## Documentation

The generated HTML documentation is available online:
- [Documentation home](https://georgtree.github.io/splitlayout/)

The repository also includes generated HTML under `docs/` and manual pages as `docs/*.n`. Open `docs/index.html` to
browse the local HTML documentation.

## Docking and undocking

```tcl
set floating [$manager undock $leaf -title "Waveform" -geometry 600x400+100+100]
set newLeaf [$manager dock $floating -right $target]
```

Only content owned by the same manager is accepted. The content frame and all its widgets survive; the old leaf ID
and, after docking, the floating token expire. Use `$manager floating` to list floating tokens, `$manager floating $token`
to inspect one, and `$manager frame $token` to access its native window.

Docking supports all six `move` destinations. Without a destination, it first tries the saved sibling position and orientation, then docks beside the root or replaces an
untouched empty placeholder created by undocking the sole root. Closing a floating window redocks it by default;
`undock -onclose destroy` or `remove $token` explicitly destroys its content. `clear` affects the docked tree only.
Destroying the manager destroys its floating windows too, because their actual Tk ancestry remains unchanged.

Content containers are now classic borderless `labelframe` widgets with class `Frame` so Tk can promote them with `wm manage`.
The surrounding hull, grips, and panedwindows retain their themed behavior. Ttk-only content-frame options such as
`-style` must instead be applied to a themed child. See the Ruff API documentation for full lifecycle, destination,
and bindtag semantics. These are public commands; floating-window drag gestures are not part of this addition.

### Floating gestures and grip buttons

Enable `-draghandles true` to show a minimal grip with monochrome arrow and cross buttons on docked and floating content.
Drag a docked grip outside the layout and release to undock. Drag a floating window's internal grip over its owner layout
to dock at an edge, sash, or outer rim; dropping at a leaf center docks to its right. Native title-bar movement does not dock.
Escape cancels; a floating drag cancellation restores its initial position.

The arrow undocks a leaf or docks floating content at the default destination. The cross always calls `remove`, deleting
content. The native window close button alone follows `-onclose dock|destroy`. Tooltips identify all three actions.
Disabling `-draghandles` hides every grip and its buttons; the public commands remain available.

The floating strip occupies the content labelframe's label-widget area, so applications can continue to use either
`pack` or `grid` inside the returned content frame. Those label-widget options are reserved for the manager.
Button styling follows ttk; existing `-dockopts` settings and Tk database resources style drag previews and hit zones.

### Header alignment and return docking

Set `-buttonside left` or `-buttonside right` (the default), at construction or using `configure`. It applies to all
docked and floating headers. Both span their available width, and the optional title uses its independent `-titlealign` setting.

```tcl
$manager configure -draghandles true -buttonside left
```

An implicit `dock`, the floating Dock button, and native close with `-onclose dock` now try the original sibling position
and split orientation. Surviving sibling nodes are tried nearest first, preferring the following sibling at equal distance.
A moved anchor is followed at its current position; a split anchor denotes its whole subtree. If all anchors have been
removed, docking fills an untouched root placeholder or falls back to the right of the root. Explicit destinations
override restoration. Original sash proportions are not restored. The delete-content button remains unconditional.

### Rectangular headers and optional titles

```tcl
$manager configure -draghandles true -headerrelief ridge -headerborderwidth 2 \
    -buttonside right -tooltips true
$manager title $leaf "Waveforms"
puts [$manager title $leaf]
$manager title $leaf "" ;# Remove the heading.
```

Headers replace the three-line indicator with a full-width rectangular surface in docked and floating windows.
Drag the title or empty header area. Buttons keep their own actions and ttk styling. Titles follow content through
swaps, moves, splits that retain it, and docking transitions. Floating tokens are accepted by `title` too.
The title is shortened visually to avoid the buttons; querying it returns the original text.
Native window titles (`undock -title`) are independent.

`-headerrelief` accepts `flat` (default), `raised`, `sunken`, `ridge`, `groove`, and `solid`.
`-headerborderwidth` defaults to `1` and accepts nonnegative integer pixels.

`-tooltips` defaults to `true`. The optional [Tklib tooltip package](https://core.tcl-lang.org/tklib/doc/trunk/embedded/md/tklib/files/modules/tooltip/tooltip.md)
provides button tooltips when it can be loaded. Otherwise there are no tooltips. Set `-tooltips false` to disable them
for this manager; other application tooltips and Tklib's global configuration are unaffected. No custom tooltip code remains.

### Title alignment, drag-area tooltips, and custom images

```tcl
set dockIcon [image create photo -file dock.svg -format svg]
set undockIcon [image create photo -file undock.png]
set deleteIcon [image create photo -file delete.png]
$manager configure -titlealign left -tooltips true \
    -buttonimages [dict create dock $dockIcon undock $undockIcon delete $deleteIcon]
```

`-titlealign` accepts `left`, `center` (default), or `right`, independently of button alignment. Long headings
are shortened within the space clear of the buttons. The drag area also gets a Tklib tooltip explaining its action;
it follows `-tooltips` and is absent when Tklib is unavailable.

`-buttonimages` accepts existing Tk image objects, not file paths. Partial dictionaries merge; use an empty image
value to restore one built-in bitmap, for example `-buttonimages {dock {}}`. An empty dictionary changes nothing.
Image validation is atomic. Supplied images remain application-owned and are never deleted, recolored, or scaled.
Button widths and header height accommodate them. Keep images alive while used and clear the override before
deleting them. Reapply an override after changing an image's dimensions in place to refresh header sizing.

## Leaf outlines

Enable `-leafborder true` to surround each leaf's header and content with one independent outline.
The header and content share the same inner left and right edges. Floating windows use the same settings.
With leaf outlines enabled, the header draws only its bottom separator, avoiding doubled top and side borders.
`-headerborderwidth` sets separator thickness and `-headerrelief` its native bottom-edge relief. Flat or zero width
hides the separator. Disabling leaf outlines restores the full header rectangle.
The outline remains when `-draghandles false`; `-showstructure` continues to describe split groups separately.
No application widgets are recreated or reparented. Geometry managers reserve the border's thickness.

```tcl
$manager configure -leafborder true -leafborderwidth 2 -leafrelief ridge
$manager configure -leafopts {-color #808080}
```

`-leafborder` defaults to false, `-leafborderwidth` to 1, and `-leafrelief` to solid.
Relief accepts flat, solid, raised, sunken, ridge, and groove. Flat or zero width hides the visible line.
`-leafopts` accepts `-color`, the classic border's base color (default #909090); raised relief shades derive
from that color, while solid relief uses Tk's solid-border rendering. It does not override ttk styles.
Set the option database resource `*splitlayoutLeafColor` (class `SplitlayoutLeafColor`) before construction
to change the default. Dictionary updates are validated atomically and retain unspecified keys.
Changes cancel active gestures and preserve content, titles, and logical split proportions.
Floating borders temporarily use the content frame's background as their base color; the prior background
is restored when the border is disabled or the window is docked.

## Minimum content sizes

```tcl
$manager minsize $leaf 200 120
puts [$manager minsize $leaf]               ;# 200 120 (content area)
puts [$manager requiredsize [$manager root]] ;# Recursive outer minimum
$manager minsize $leaf 0 0                  ;# Clear the content-area minimum
```

`minsize id ?width height?` accepts a leaf or an owned floating token. Both dimensions must be supplied together
as nonnegative integer pixels; the default is `{0 0}`. Splits have calculated requirements, not independently
assignable minima. Values belong to content: they follow swaps, moves, the child selected by `split -keep`, and
undocking/redocking. A newly created leaf starts at `{0 0}`. Removing content removes its stored minimum.

`requiredsize id` accepts a leaf, split, or floating token and returns `{width height}`. It adds header/button
space and leaf borders to the content minimum. For a horizontal split, child widths and themed sash widths are
summed and the largest child height is used. Vertical splits use the opposite axes. Each split's structure border
and padding are added when enabled. Removing, inserting, or moving children updates the calculated requirement.
The query excludes the manager hull's padding/border, native window decorations, and application widget requests.
It works before mapping; sash dimensions come from the active ttk theme without modifying its styles.

With explicit minima configured, requested proportions are fitted to available space while respecting child
requirements. Both live and deferred sash gestures stop at the adjacent panes' feasible limits. When the parent
is too small, child requirements along each split axis are compressed proportionally; requested minima are retained
and apply again when space becomes available. A cross-axis shortage likewise cannot satisfy the requested minimum.
Very small allocations may leave no visible content after sashes and decoration consume the available pixels.
Setting `{0 0}` clears the content requirement; enabled headers and borders still require space.
Layouts that have never been assigned minima retain their existing sash behavior.

Floating windows receive `wm minsize` based on their content and decoration. Header visibility, image sizes, border
settings, and theme changes refresh constraints through the normal idle geometry pass. The manager does **not** set
`wm minsize` on the application's owning toplevel: applications can use `requiredsize` and account for their other
widgets if they want to enforce a window minimum. Native window-manager behavior remains platform-dependent. Tk may report a larger
minimum than requested because of native window limits. In particular, Windows can report a positive minimum
width after setting `wm minsize` to `0 0`, and its reported limits can change when a window is first mapped.
`requiredsize` reports the manager's calculated requirement, not the native effective window minimum.
Constraints cover manager operations and gestures; direct modifications through the exposed native panedwindow
command bypass the manager until its next geometry application.
