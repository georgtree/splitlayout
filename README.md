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
content. Surviving frames retain their widgets and state.

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
with Tk geometry managers. The constructor accepts `-width`, `-height`, `-opaqueresize`, `-sashpreview`, `-draghandles`, and `-showstructure`.

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

### Moving panes
`move` relocates an existing leaf while retaining its identifier, content frame, widget pathnames, and application
state. Supply exactly one destination option:

| Destination      | Effect                                                         |
|------------------|----------------------------------------------------------------|
| `-left target`   | Place the source to the left of a target leaf or split.        |
| `-right target`  | Place the source to the right of a target leaf or split.       |
| `-top target`    | Place the source above a target leaf or split.                 |
| `-bottom target` | Place the source below a target leaf or split.                 |
| `-before target` | Insert before a non-root leaf or split in its existing parent. |
| `-after target`  | Insert after a non-root leaf or split in its existing parent.  |

For example, in the layout built above:

```tcl
# Insert the middle pane above the bottom pane in the existing vertical split.
.layout move $middle -top $bottom

# Insert it before the entire right-hand region in the root split.
.layout move $middle -before $right
```

Edge destinations reuse the target's parent when it already has the required orientation. Otherwise, a target leaf
becomes a new split containing the source and a new leaf for the target's existing content. This follows `split`'s
identifier semantics: the target identifier now denotes a split. Use `children`, `leaves`, or `locate` to obtain the
new target-content leaf identifier. If the target is already a split, a new parent split is created around the
source and target subtree; the target keeps its identifier unless source removal leaves it with a sole child and
normal collapse promotes that child. A split target may contain the source, including the root. For example,
`.layout move $source -right [.layout root]` places the source beside the remaining layout in a new horizontal root.
The source identifier remains unchanged and is also the command's return value.

For example, a perpendicular move in a two-pane horizontal layout changes it to a vertical layout:

```tcl
splitlayout .example
pack .example -fill both -expand 1
lassign [.example split [.example root] -orient horizontal] a b
set moved [.example move $a -top $b]
# moved equals a; b is now the root vertical split.
```

`-before` and `-after` always use the existing parent orientation. They can describe a sash destination without pixel
coordinates: insertion at a sash is `-before` its following child or `-after` its preceding child. A split target may
contain the source; moving beside that ancestor moves the source outside its subtree. Insertion beside the root is
an error, except that any move to oneself is a no-op.

Reordering within the same parent preserves the pane weights associated with each node. Other moves divide the
target's share equally between the source and target. Remaining siblings in the source parent retain their relative
weights. If only one child remains there, it replaces the old parent after insertion; that old parent identifier
becomes invalid. Query `root` again after a move that can collapse the root.

Moving to oneself or to an already adjacent position with the requested orientation does nothing. Invalid arguments
are rejected before modifying the layout. A structural move cancels an active deferred sash gesture, rebuilds geometry
once, and lets geometry settle through the normal event loop. No application content is destroyed.

`move` changes pane placement; `swap` exchanges content at two existing positions.

### Dragging panes
Enable minimal, manager-owned grips for every leaf with the global `-draghandles` property:

```tcl
splitlayout .docking -draghandles true -opaqueresize false
pack .docking -fill both -expand 1
lassign [.docking split [.docking root]] first second

# The existing content API is unchanged.
set f [.docking frame $first]
text $f.editor
pack $f.editor -fill both -expand 1

# Hide all grips and reclaim their space, including for leaves created later.
.docking configure -draghandles false
```

The default is `false`. When enabled, each leaf has a narrow strip containing a centered three-line grip, with no
text or buttons. The grip uses ttk theme colors and a height scaled to Tk's display scaling. Application widgets
remain entirely inside the frame returned by `frame`; pack and grid configurations there survive toggles and moves.

Press the left mouse button on a grip and move at least five pixels to start dragging. The entire strip accepts the
press; content widgets retain their own mouse bindings. The destination is selected within this megawidget:

| Drop location                                    | Operation                                                  | Preview                              |
|--------------------------------------------------|------------------------------------------------------------|--------------------------------------|
| Another leaf's center                            | Swap the two content frames.                               | Outline of the destination pane.     |
| Left, right, top, or bottom edge of another leaf | Move beside that leaf using the corresponding edge option. | Narrow band at the chosen edge.      |
| Outer rim of the megawidget                      | Move outside the entire layout region on that side.        | Full-height or full-width edge band. |
| A native sash between panes                      | Insert before the child following that sash.               | Insertion line at the sash.          |
| Source leaf or outside the megawidget            | Cancel.                                                    | No destination highlight.            |

The outermost 12 pixels **inside** the megawidget form an outer drop zone (limited to one eighth of its size). This
zone takes precedence over sashes and local leaf edges. It allows moving a pane to the far right or left of an entire
stacked region, or above/below an entire row. A matching root orientation reuses that split's first or last position;
otherwise a new root split is created. Drop just inside the window: points outside the megawidget still cancel.

Farther inside, sashes take precedence over leaf edge zones. Local edge zones extend up to 24 pixels into a pane,
limited to one quarter of its width or height; corners choose the nearest normalized edge. The blue preview is temporary
and does not resize or rearrange content during dragging. Release performs one `move` or `swap`; a click without
dragging does nothing.  The `-sashpreview` setting controls deferred sash resizing only, not this docking preview.

Escape, loss of grip focus, hiding or resizing panes, moving or hiding the containing window, structural layout
changes, or disabling `-draghandles` cancels the gesture. The grip temporarily takes keyboard focus and a local mouse
grab so that release outside the grip and Escape are handled. Cleanup restores the prior focus when still owned by
the grip and releases only its own grab. A new gesture does not replace an existing grab. Dragging between separate
splitlayout instances or to other applications is not supported.

With handles enabled, `widget leaf` returns the **pane wrapper**, whereas `frame leaf` always returns the application
content frame. `container leaf` resolves the wrapper's outer geometry container; `container $contentFrame` resolves
the wrapper that packs the content. `node` recognizes either pathname. `locate` resolves application widgets and
manager-owned grips to their current leaf. Logical `tree` snapshots expose both `widget` and `frame`; actual `widgets`
snapshots also include the wrappers, grip canvases, and any temporary preview frames.

The wrapper and grip stay at their leaf position during a swap; only content frames are exchanged. A move preserves
the moved leaf and its wrapper, while normal split/collapse rules may replace destination wrappers. Disabling handles
removes wrappers; do not cache wrapper or grip paths across layout changes. Application content paths remain stable.

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

## Visual structure
Enable outlines for the whole layout to distinguish flat sibling arrangements from nested groups:

```tcl
.layout configure -showstructure true
# Also accepted at construction:
splitlayout .outlined -draghandles true -showstructure true
```

Each split receives a one-pixel gray outline and two pixels of inner spacing, giving a three-pixel inset on each side.
Flat siblings share one enclosing outline; a nested split has an additional inset outline around its children. A sole
root leaf has no split outline. The setting is independent of drag handles and applies to future splits. During
docking, the receiving group outline turns blue alongside the existing destination preview. For a local edge move that
creates a new split, the highlighted outline is the current enclosing group. Escape, an invalid destination, and release
restore the normal outline color.

Changing `-showstructure` cancels active gestures and rebuilds geometry while retaining content, native panedwindows,
and split proportions (subject to available pixel space). Disabling it removes the outlines and their spacing.
Very small panes can still collapse under Tk's normal geometry constraints.

With this option enabled, `widget split` returns the enclosing outline frame. Use `panedwindow split` to obtain the
native ttk panedwindow regardless of the option value, for example:

```tcl
set split [.layout root]
set pw [.layout panedwindow $split]
set position [$pw sashpos 0]
```

`node` recognizes both paths. `container split` returns the outer geometry container, while `container $pw` returns
the outline frame that packs the native panedwindow. `tree` includes both `widget` and `panedwindow` for splits;
`widgets` exposes the actual geometry containers. Outline frames remain immediate Tk children of the hull.

## Resizing

| Option           | Default  | Meaning                                                 |
|------------------|----------|---------------------------------------------------------|
| `-width`         | `800`    | Nonnegative requested hull width in pixels.             |
| `-height`        | `600`    | Nonnegative requested hull height in pixels.            |
| `-opaqueresize`  | `true`   | Resize pane content continuously while dragging a sash. |
| `-sashpreview`   | `window` | Deferred preview mode: `window`, `inline`, or `none`.   |
| `-draghandles`   | `false`  | Show docking grips on all current and future leaves.    |
| `-showstructure` | `false`  | Outline and inset all current and future splits.        |

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

The class uses `oo::configurable` properties directly, without creating option objects. Query a property with
`configure -name`. With no arguments, `configure` returns a dictionary
of property names and current values, rather than Tk-style option descriptors:

```tcl
set preview [.layout configure -sashpreview]
set properties [.layout configure]
.layout configure -opaqueresize false -padding 4
```

The hull properties `-width`, `-height`, `-padding`, `-borderwidth`, `-relief`, `-cursor`, `-takefocus`, and `-style`
delegate to the ttk frame. `-class` is read-only. The constructor accepts the six creation options listed above;
other writable properties can be set after construction. No Tk option-database resources are added for
`-opaqueresize`, `-sashpreview`, `-draghandles`, or `-showstructure`.

Native property setters run in argument order. If a later value is invalid, earlier successful changes remain in
effect. Invalid resizing values leave that property's value and any active drag unchanged; changing a valid resizing
value cancels the active drag. Setting the same value preserves it.

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

For a non-root node identifier, `container` returns its parent panedwindow. Its actual Tk parent remains `.layout`.
With handles enabled, passing the content frame pathname instead returns its pane wrapper.
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
`frame`. Splits contain `panedwindow`, `orient`, and `proportions`, plus `ratio` when they have two children. Split `children` are nested
node dictionaries in pane order.

`widgets` returns nested dictionaries containing `path`, `parent`, `class`, `manager`, `container`, and `children`.
It includes application widgets. The container is resolved for layout nodes and for widgets managed by pack, grid,
or place; it is empty for other managers without a supported reverse lookup.

Both snapshots are for inspection. They do not serialize application widget state or provide a restore operation.
