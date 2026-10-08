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
- Relative pane proportions and interactive sash resizing.
- Live resizing or deferred resizing with a configurable sash preview.
- Inspection of both the logical layout tree and the actual Tk widget hierarchy.

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

All managed content frames and split panedwindows are immediate Tk children of the layout hull. Application widgets
are descendants of their content frame. Splitting, promoting, or swapping content changes its logical placement and
geometry container, while its actual Tk parent and widget pathnames stay the same.

Removing a content frame destroys that frame and its application widgets. Destroying the layout destroys all its
content. Surviving frames retain their widgets and state.

## Requirements

- Tcl and Tk; the source accepts version 8.6 or newer and development targets Tcl/Tk 9.1.
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

## Quick start
```tcl
package require splitlayout

wm title . {Split layout example}
wm geometry . 900x600

splitlayout .layout -width 900 -height 600
pack .layout -fill both -expand 1

set root [.layout root]
lassign [.layout split $root -orient horizontal -ratio 0.4 -keep first] left right

set leftFrame [.layout frame $left]
set rightFrame [.layout frame $right]

text $leftFrame.editor -width 20 -height 10 -wrap word
$leftFrame.editor insert end {Content in the left pane.}
pack $leftFrame.editor -fill both -expand 1

text $rightFrame.editor -width 20 -height 10 -wrap word
$rightFrame.editor insert end {Content in the right pane. Drag the sash to resize.}
pack $rightFrame.editor -fill both -expand 1
```

The `splitlayout .layout ...` command returns the widget pathname. Use that pathname both as the layout command and
with Tk geometry managers. The constructor accepts `-width`, `-height`, `-opaqueresize`, and `-sashpreview`.

### Splitting existing content
Continue from the quick-start example:

```tcl
lassign [.layout split $right -orient vertical -ratio 0.65 -keep first] top bottom

set bottomFrame [.layout frame $bottom]
ttk::label $bottomFrame.status -text {New bottom pane}
pack $bottomFrame.status -fill both -expand 1
```

The original right-hand editor remains in `$top`, with the same widget pathname and state. `$right` now identifies
the parent split; `$top` and `$bottom` are new leaf identifiers. `-keep second` would retain the editor in the second
child instead. Both children are returned in pane order.

### Adding panes at the same level
Insert beside a leaf or a split, provided that it has a parent:

```tcl
set middle [.layout insert $left -side after]
set middleFrame [.layout frame $middle]
ttk::label $middleFrame.label -text {Middle pane}
pack $middleFrame.label -fill both -expand 1

# The root now has three children: left, middle, and the right-hand split.
.layout proportions $root {2 1 3}
```

Insertion divides the target child's existing share equally between that child and the new leaf. The `-side` option
accepts `before` or `after`, with `after` as the default. To add panes when the root is still a leaf, split it first.

`proportions` accepts one finite positive weight per immediate child and normalizes the weights. The example assigns
shares of 2/6, 1/6, and 3/6. For a split with exactly two children, `ratio` queries or sets the first child's fraction:

```tcl
.layout ratio $right 0.7
set fraction [.layout ratio $right]
set shares [.layout proportions $root]
```

Geometry changes settle through Tk's event loop. Immediately after setting proportions, a query can return the stored
values before the sashes have moved.

### Swapping and removing content
The following operations continue the example above:

```tcl
# Exchange complete content frames across different nesting levels.
.layout swap $left $bottom

# Remove the middle pane and all widgets it contains.
set survivingParent [.layout remove $middle]

# Keep top, destroy its sibling subtree, and replace their parent with top.
.layout retain $top
```

`swap` exchanges content frames; node identifiers continue to identify the same logical positions. Cached frame and
application-widget pathnames remain valid, but may now belong to a different leaf.

`remove` destroys the requested subtree. If its parent has only one child left, that child replaces the parent.
`retain` destroys all siblings of the retained node and collapses its immediate parent; it does not collapse all
ancestors. Retaining the root does nothing.

To discard all content and start again:

```tcl
set root [.layout clear]
```

Previously removed node identifiers are invalid. Use the return values or query the layout again after structural
changes. To destroy the entire layout, use `.layout destroy` or `destroy .layout`.

## Resizing

| Option          | Default  | Meaning                                                 |
|-----------------|----------|---------------------------------------------------------|
| `-width`        | `800`    | Nonnegative requested hull width in pixels.             |
| `-height`       | `600`    | Nonnegative requested hull height in pixels.            |
| `-opaqueresize` | `true`   | Resize pane content continuously while dragging a sash. |
| `-sashpreview`  | `window` | Deferred preview mode: `window`, `inline`, or `none`.   |

Enable deferred resizing at construction or through `configure`:

```tcl
.layout configure -opaqueresize false -sashpreview window
```

In deferred mode, dragging changes only the preview target. Releasing the mouse commits the sash position and resizes
the content. Escape cancels the gesture. Changing layout structure or resizing mode, unmapping the pane, or changing
geometry in a way that invalidates the gesture also cancels it.

| Preview mode | Behavior                                                            |
|--------------|---------------------------------------------------------------------|
| `window`     | Uses a temporary borderless transient toplevel for the sash marker. |
| `inline`     | Uses a frame inside the layout for the sash marker.                 |
| `none`       | Defers resizing without displaying a marker.                        |

Preview motion is coalesced at idle. `window` can reduce content exposures on composited desktops, but appearance
depends on Tk and the window manager; it does not guarantee atomic repainting of application widgets.

These options apply to current and future splits. Deferred mode affects sash dragging; resizing the containing
window and programmatic sizing still update the layout normally. Very small containers can collapse panes; there is
no per-pane minimum-size API.

`configure` and `cget` also expose the ttk frame hull options. Additional hull options can be set after construction.

## Inspecting the layout
Use logical node identifiers when working with the layout structure, and widget pathnames when working with Tk:

```tcl
set leaf [lindex [.layout leaves] 0]
set contentFrame [.layout frame $leaf]

set logicalParent [.layout parent $leaf]
set geometryContainer [.layout container $leaf]
set actualParent [winfo parent $contentFrame]

set layoutTree [.layout tree]
set widgetTree [.layout widgets]
```

For a non-root node, `container` returns its parent panedwindow. Its actual Tk parent remains `.layout`.
`winfo manager` reports the manager name, not the pathname of that geometry container.

`node` maps an exact managed frame or panedwindow pathname to its node identifier. `locate` accepts a descendant
application widget and walks its Tk parents to find the containing leaf:

```tcl
set leaf [.layout node $contentFrame]
# For any existing application widget inside a content frame:
set applicationWidget [lindex [winfo children $contentFrame] 0]
if {$applicationWidget ne {}} {
    set leaf [.layout locate $applicationWidget]
}
```

`tree` returns nested dictionaries containing `id`, `type`, `parent`, `widget`, and `children`. Leaves also contain
`frame`. Splits contain `orient` and `proportions`, plus `ratio` when they have two children. Split `children` are nested
node dictionaries in pane order.

`widgets` returns nested dictionaries containing `path`, `parent`, `class`, `manager`, `container`, and `children`.
It includes application widgets. The container is resolved for layout nodes and for widgets managed by pack, grid,
or place; it is empty for other managers without a supported reverse lookup.

Both snapshots are for inspection. They do not serialize application widget state or provide a restore operation.
