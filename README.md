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
- Optional textless grips for mouse-driven swaps, edge moves, and insertion at sashes.
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
docked and floating headers. Both span their available width, and the grip indicator stays centered in the full header.

```tcl
$manager configure -draghandles true -buttonside left
```

An implicit `dock`, the floating Dock button, and native close with `-onclose dock` now try the original sibling position
and split orientation. Surviving sibling nodes are tried nearest first, preferring the following sibling at equal distance.
A moved anchor is followed at its current position; a split anchor denotes its whole subtree. If all anchors have been
removed, docking fills an untouched root placeholder or falls back to the right of the root. Explicit destinations
override restoration. Original sash proportions are not restored. The delete-content button remains unconditional.
