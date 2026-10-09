# splitlayout.tcl -- Multi-pane split layout megawidget (TclOO).
package require Tcl 9.0-
package require Tk 9.0-
package require argparse

package provide splitlayout 0.1

namespace eval ::splitlayout {
    variable libDir [file dirname [file normalize [info script]]]

    variable _ruff_ns_opts {
        -heading {splitlayout}
        -includeprivate false
    }

    variable _ruff_preamble {
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

        The `splitlayout .layout ...` command returns the widget pathname. Use that pathname both as the layout command
        and with Tk geometry managers. The constructor accepts `-width`, `-height`, `-opaqueresize`, `-sashpreview`,
        `-draghandles`, `-showstructure`, `-dockopts`, `-structureopts`, and `-sashpreviewopts`.

        ## Splitting existing content
        Continue from the quick-start example:

        ```tcl
        lassign [.layout split $right -orient vertical -ratio 0.65 -keep first] top bottom

        set bottomFrame [.layout frame $bottom]
        ttk::label $bottomFrame.status -text {New bottom pane}
        pack $bottomFrame.status -fill both -expand 1
        ```

        The original right-hand editor remains in `$top`, with the same widget pathname and state. `$right` now
        identifies the parent split; `$top` and `$bottom` are new leaf identifiers. `-keep second` would retain the
        editor in the second child instead. Both children are returned in pane order.

        ## Adding panes at the same level
        Insert beside a leaf or a split, provided that it has a parent:

        ```tcl
        set middle [.layout insert $left -side after]
        set middleFrame [.layout frame $middle]
        ttk::label $middleFrame.label -text {Middle pane}
        pack $middleFrame.label -fill both -expand 1

        # The root now has three children: left, middle, and the right-hand split.
        .layout proportions $root {2 1 3}
        ```

        Insertion divides the target child's existing share equally between that child and the new leaf. The `-side`
        option accepts `before` or `after`, with `after` as the default. To add panes when the root is still a leaf,
        split it first.

        `proportions` accepts one finite positive weight per immediate child and normalizes the weights. The example
        assigns shares of 2/6, 1/6, and 3/6. For a split with exactly two children, `ratio` queries or sets the first
        child's fraction:

        ```tcl
        .layout ratio $right 0.7
        set fraction [.layout ratio $right]
        set shares [.layout proportions $root]
        ```

        Geometry changes settle through Tk's event loop. Immediately after setting proportions, a query can return the
        stored values before the sashes have moved.

        ## Moving panes
        `move` relocates an existing leaf while retaining its identifier, content frame, widget pathnames, and
        application state. Supply exactly one destination option:

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

        Edge destinations reuse the target's parent when it already has the required orientation. Otherwise, a target
        leaf becomes a new split containing the source and a new leaf for the target's existing content. This follows
        `split`'s identifier semantics: the target identifier now denotes a split. Use `children`, `leaves`, or
        `locate` to obtain the new target-content leaf identifier. If the target is already a split, a new parent split
        is created around the source and target subtree; the target keeps its identifier unless source removal leaves
        it with a sole child and normal collapse promotes that child. A split target may contain the source, including
        the root. For example, `.layout move $source -right [.layout root]` places the source beside the remaining
        layout in a new horizontal root.  The source identifier remains unchanged and is also the command's return
        value.

        For example, a perpendicular move in a two-pane horizontal layout changes it to a vertical layout:

        ```tcl
        splitlayout .example
        pack .example -fill both -expand 1
        lassign [.example split [.example root] -orient horizontal] a b
        set moved [.example move $a -top $b]
        # moved equals a; b is now the root vertical split.
        ```

        `-before` and `-after` always use the existing parent orientation. They can describe a sash destination without
        pixel coordinates: insertion at a sash is `-before` its following child or `-after` its preceding child. A
        split target may contain the source; moving beside that ancestor moves the source outside its
        subtree. Insertion beside the root is an error, except that any move to oneself is a no-op.

        Reordering within the same parent preserves the pane weights associated with each node. Other moves divide the
        target's share equally between the source and target. Remaining siblings in the source parent retain their
        relative weights. If only one child remains there, it replaces the old parent after insertion; that old parent
        identifier becomes invalid. Query `root` again after a move that can collapse the root.

        Moving to oneself or to an already adjacent position with the requested orientation does nothing. Invalid
        arguments are rejected before modifying the layout. A structural move cancels an active deferred sash gesture,
        rebuilds geometry once, and lets geometry settle through the normal event loop. No application content is
        destroyed.

        `move` changes pane placement; `swap` exchanges content at two existing positions.

        ## Dragging panes
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

        The default is `false`. When enabled, each leaf has a narrow strip containing a centered three-line grip, with
        no text or buttons. The grip uses ttk theme colors and a height scaled to Tk's display scaling. Application
        widgets remain entirely inside the frame returned by `frame`; pack and grid configurations there survive
        toggles and moves.

        Press the left mouse button on a grip and move at least five pixels (the default `-dockopts -threshold`) to
        start dragging. The entire strip accepts the press; content widgets retain their own mouse bindings. The
        destination is selected within this megawidget:

        | Drop location                                    | Operation                                                  | Preview                              |
        |--------------------------------------------------|------------------------------------------------------------|--------------------------------------|
        | Another leaf's center                            | Swap the two content frames.                               | Outline of the destination pane.     |
        | Left, right, top, or bottom edge of another leaf | Move beside that leaf using the corresponding edge option. | Narrow band at the chosen edge.      |
        | Outer rim of the megawidget                      | Move outside the entire layout region on that side.        | Full-height or full-width edge band. |
        | A native sash between panes                      | Insert before the child following that sash.               | Insertion line at the sash.          |
        | Source leaf or outside the megawidget            | Cancel.                                                    | No destination highlight.            |

        By default, the outermost 12 pixels **inside** the megawidget form an outer drop zone (limited to one eighth of
        its size). This zone takes precedence over sashes and local leaf edges. It allows moving a pane to the far
        right or left of an entire stacked region, or above/below an entire row. A matching root orientation reuses
        that split's first or last position; otherwise a new root split is created. Drop just inside the window: points
        outside the megawidget still cancel.

        Farther inside, sashes take precedence over leaf edge zones. Local edge zones default to up to 24 pixels into a
        pane, limited to one quarter of its width or height; corners choose the nearest normalized edge. The preview is
        blue by default, is temporary, and does not resize or rearrange content during dragging. Release performs one
        `move` or `swap`; a click without dragging does nothing.  The `-sashpreview` setting controls deferred sash
        resizing only, not this docking preview.

        Escape, loss of grip focus, hiding or resizing panes, moving or hiding the containing window, structural layout
        changes, or disabling `-draghandles` cancels the gesture. The grip temporarily takes keyboard focus and a local
        mouse grab so that release outside the grip and Escape are handled. Cleanup restores the prior focus when still
        owned by the grip and releases only its own grab. A new gesture does not replace an existing grab. Dragging
        between separate splitlayout instances or to other applications is not supported.

        With handles enabled, `widget leaf` returns the **pane wrapper**, whereas `frame leaf` always returns the
        application content frame. `container leaf` resolves the wrapper's outer geometry container; `container
        $contentFrame` resolves the wrapper that packs the content. `node` recognizes either pathname. `locate`
        resolves application widgets and manager-owned grips to their current leaf. Logical `tree` snapshots expose
        both `widget` and `frame`; actual `widgets` snapshots also include the wrappers, grip canvases, and any
        temporary preview frames.

        The wrapper and grip stay at their leaf position during a swap; only content frames are exchanged. A move
        preserves the moved leaf and its wrapper, while normal split/collapse rules may replace destination
        wrappers. Disabling handles removes wrappers; do not cache wrapper or grip paths across layout
        changes. Application content paths remain stable.

        ## Swapping and removing content
        The following operations continue the example above:

        ```tcl
        # Exchange complete content frames across different nesting levels.
        .layout swap $left $bottom

        # Remove the middle pane and all widgets it contains.
        set survivingParent [.layout remove $middle]

        # Keep top, destroy its sibling subtree, and replace their parent with top.
        .layout retain $top
        ```

        `swap` exchanges content frames; node identifiers continue to identify the same logical positions. Cached frame
        and application-widget pathnames remain valid, but may now belong to a different leaf.

        `remove` destroys the requested subtree. If its parent has only one child left, that child replaces the parent.
        `retain` destroys all siblings of the retained node and collapses its immediate parent; it does not collapse all
        ancestors. Retaining the root does nothing.

        To discard all content and start again:

        ```tcl
        set root [.layout clear]
        ```

        Previously removed node identifiers are invalid. Use the return values or query the layout again after
        structural changes. To destroy the entire layout, use `.layout destroy` or `destroy .layout`.

        ## Visual structure
        Enable outlines for the whole layout to distinguish flat sibling arrangements from nested groups:

        ```tcl
        .layout configure -showstructure true
        # Also accepted at construction:
        splitlayout .outlined -draghandles true -showstructure true
        ```

        By default, each split receives a one-pixel gray outline and two pixels of inner spacing, giving a three-pixel
        inset on each side.  Customize these dimensions and colors with `-structureopts` or the option database
        described below.  Flat siblings share one enclosing outline; a nested split has an additional inset outline
        around its children. A sole root leaf has no split outline. The setting is independent of drag handles and
        applies to future splits. During docking, the receiving group outline turns blue alongside the existing
        destination preview. For a local edge move that creates a new split, the highlighted outline is the current
        enclosing group. Escape, an invalid destination, and release restore the normal outline color.

        Changing `-showstructure` cancels active gestures and rebuilds geometry while retaining content, native
        panedwindows, and split proportions (subject to available pixel space). Disabling it removes the outlines and
        their spacing.  Very small panes can still collapse under Tk's normal geometry constraints.

        With this option enabled, `widget split` returns the enclosing outline frame. Use `panedwindow split` to obtain
        the native ttk panedwindow regardless of the option value, for example:

        ```tcl
        set split [.layout root]
        set pw [.layout panedwindow $split]
        set position [$pw sashpos 0]
        ```

        `node` recognizes both paths. `container split` returns the outer geometry container, while `container $pw`
        returns the outline frame that packs the native panedwindow. `tree` includes both `widget` and `panedwindow`
        for splits; `widgets` exposes the actual geometry containers. Outline frames remain immediate Tk children of
        the hull.

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

        In deferred mode, dragging changes only the preview target. Releasing the mouse commits the sash position and
        resizes the content. Escape cancels the gesture. Changing layout structure or resizing mode, unmapping the
        pane, or changing geometry in a way that invalidates the gesture also cancels it.

        | Preview mode | Behavior                                                            |
        |--------------|---------------------------------------------------------------------|
        | `window`     | Uses a temporary borderless transient toplevel for the sash marker. |
        | `inline`     | Uses a frame inside the layout for the sash marker.                 |
        | `none`       | Defers resizing without displaying a marker.                        |

        Preview motion is coalesced at idle. `window` can reduce content exposures on composited desktops, but
        appearance depends on Tk and the window manager; it does not guarantee atomic repainting of application
        widgets.

        These options apply to current and future splits. Deferred mode affects sash dragging; resizing the containing
        window and programmatic sizing still update the layout normally. Very small containers can collapse panes;
        there is no per-pane minimum-size API.

        The class uses `oo::configurable` properties directly, without creating option objects. Query a property with
        `configure -name`. With no arguments, `configure` returns a dictionary of property names and current values,
        rather than Tk-style option descriptors:

        ```tcl
        set preview [.layout configure -sashpreview]
        set properties [.layout configure]
        .layout configure -opaqueresize false -padding 4
        ```

        The hull properties `-width`, `-height`, `-padding`, `-borderwidth`, `-relief`, `-cursor`, `-takefocus`, and
        `-style` delegate to the ttk frame. `-class` is read-only. The constructor accepts the six creation options
        listed above and the three appearance dictionaries described below; other writable properties can be set after
        construction. No Tk option-database resources are added for `-opaqueresize`, `-sashpreview`, `-draghandles`, or
        `-showstructure`.

        Native property setters run in argument order. If a later value is invalid, earlier successful changes remain
        in effect. Invalid resizing values leave that property's value and any active drag unchanged; changing a valid
        resizing value cancels the active drag. Setting the same value preserves it.

        ## Appearance and drag detection
        Manager-owned decoration and drag detection settings follow graphtoolbar's Tk option-database convention:
        package-specific resource names, defaults registered at `widgetDefault` priority, and dictionary properties for
        explicit per-instance overrides. No option instances are created.

        ```tcl
        package require splitlayout

        option add *splitlayoutDockColor orange userDefault
        option add *splitlayoutDockOuterWidth 20 userDefault
        option add *splitlayoutDockEdgeWidth 32 userDefault
        option add *splitlayoutStructureColor gray55 userDefault
        option add *splitlayoutStructureActiveColor orange userDefault

        splitlayout::splitlayout .layout -draghandles true -showstructure true \
            -dockopts {-threshold 8} -structureopts {-padding 3}
        pack .layout -fill both -expand 1

        # Partial updates keep all unspecified settings.
        .layout configure -dockopts {-color purple -outerwidth 24}
        .layout configure -sashpreviewopts {-color gray40 -width 5}
        set docking [.layout configure -dockopts]
        ```

        | Property           | Key            | Resource name                     | Resource class                    | Default   |
        |--------------------|----------------|-----------------------------------|-----------------------------------|-----------|
        | `-dockopts`        | `-color`       | `splitlayoutDockColor`            | `SplitlayoutDockColor`            | `#448aff` |
        | `-dockopts`        | `-linewidth`   | `splitlayoutDockLineWidth`        | `SplitlayoutDockLineWidth`        | `3`       |
        | `-dockopts`        | `-edgewidth`   | `splitlayoutDockEdgeWidth`        | `SplitlayoutDockEdgeWidth`        | `24`      |
        | `-dockopts`        | `-outerwidth`  | `splitlayoutDockOuterWidth`       | `SplitlayoutDockOuterWidth`       | `12`      |
        | `-dockopts`        | `-threshold`   | `splitlayoutDockThreshold`        | `SplitlayoutDockThreshold`        | `5`       |
        | `-structureopts`   | `-color`       | `splitlayoutStructureColor`       | `SplitlayoutStructureColor`       | `#909090` |
        | `-structureopts`   | `-activecolor` | `splitlayoutStructureActiveColor` | `SplitlayoutStructureActiveColor` | `#448aff` |
        | `-structureopts`   | `-borderwidth` | `splitlayoutStructureBorderWidth` | `SplitlayoutStructureBorderWidth` | `1`       |
        | `-structureopts`   | `-padding`     | `splitlayoutStructurePadding`     | `SplitlayoutStructurePadding`     | `2`       |
        | `-sashpreviewopts` | `-color`       | `splitlayoutSashPreviewColor`     | `SplitlayoutSashPreviewColor`     | `#606060` |
        | `-sashpreviewopts` | `-width`       | `splitlayoutSashPreviewWidth`     | `SplitlayoutSashPreviewWidth`     | `3`       |

        The database is queried against the layout hull once during construction. Standard Tk name/class patterns and
        priorities apply; for example, `*editor.layout.splitlayoutDockColor` scopes a resource to a layout below
        `.editor`.  Explicit constructor dictionary keys override database values. Later database changes affect newly
        created layouts only; use `configure` for an existing layout. Built-in defaults are still available if the
        application calls `option clear`.  The three dictionaries are accepted both at construction and by `configure`;
        an empty dictionary leaves current settings unchanged.

        All dimensions are integer **screen pixels**, from zero to 2147483647, without additional DPI scaling. Colors
        must be valid Tk colors. Preview line widths (`-dockopts -linewidth` and `-sashpreviewopts -width`) must be at
        least one.

        - `-dockopts -color` colors all docking preview rectangles. `-linewidth` controls the center-swap outline and
        sash insertion line; edge-preview bands use the corresponding detection width. Preview strokes are clipped to
        the region.
        - `-outerwidth` specifies the band inside the hull for docking beside the entire layout, capped at one eighth
        of each hull dimension. Zero disables outer docking zones.
        - `-edgewidth` specifies each leaf's local edge band, capped at one quarter of each leaf dimension. Zero
        disables local edge moves, allowing center swaps there instead. Native sash and outer-zone precedence remain
        unchanged.
        - `-threshold` specifies the minimum movement along either screen axis before a grip drag activates. Zero
        activates on the first motion event; pressing and releasing without motion still does nothing.
        - `-structureopts` controls the normal and receiving-group outline colors, border thickness, and inner spacing.
        The inset per side is `-borderwidth + -padding`. A zero border width hides the outline; padding can also be
        zero.
        - `-sashpreviewopts` controls the manager's deferred-resize marker in both `window` and `inline` modes; `none`
        remains invisible.

        Dictionary updates validate all supplied values before changing anything. An invalid key, color, or distance
        leaves that dictionary and any active gesture intact. Successful changes cancel active gestures; unchanged
        assignments do nothing. Structure changes rebuild geometry while retaining content and proportions. Each
        dictionary update is atomic; separate property/value pairs retain the usual ordered `oo::configurable`
        behavior.

        These settings do not alter ttk styles, grip colors, or native sash appearance and hit areas. The existing
        behavior properties (`-draghandles`, `-showstructure`, `-opaqueresize`, and `-sashpreview`) remain separate
        from database styling.

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

        For a non-root node identifier, `container` returns its parent panedwindow. Its actual Tk parent remains
        `.layout`.  With handles enabled, passing the content frame pathname instead returns its pane wrapper. `winfo
        manager` reports the manager name, not the pathname of that geometry container.

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

        `tree` returns nested dictionaries containing `id`, `type`, `parent`, `widget`, and `children`. Leaves also
        contain `frame`. Splits contain `panedwindow`, `orient`, and `proportions`, plus `ratio` when they have two
        children. Split `children` are nested node dictionaries in pane order.

        `widgets` returns nested dictionaries containing `path`, `parent`, `class`, `manager`, `container`, and
        `children`.  It includes application widgets. The container is resolved for layout nodes and for widgets
        managed by pack, grid, or place; it is empty for other managers without a supported reverse lookup.

        Both snapshots are for inspection. They do not serialize application widget state or provide a restore
        operation.
    }

    # Names are package-specific; native ttk resources and styles are untouched.
    variable appearanceResources {
        dockopts {
            -color {splitlayoutDockColor color #448aff}
            -linewidth {splitlayoutDockLineWidth positive 3}
            -edgewidth {splitlayoutDockEdgeWidth nonnegative 24}
            -outerwidth {splitlayoutDockOuterWidth nonnegative 12}
            -threshold {splitlayoutDockThreshold nonnegative 5}
        }
        structureopts {
            -color {splitlayoutStructureColor color #909090}
            -activecolor {splitlayoutStructureActiveColor color #448aff}
            -borderwidth {splitlayoutStructureBorderWidth nonnegative 1}
            -padding {splitlayoutStructurePadding nonnegative 2}
        }
        sashpreviewopts {
            -color {splitlayoutSashPreviewColor color #606060}
            -width {splitlayoutSashPreviewWidth positive 3}
        }
    }
    dict for {group entries} $appearanceResources {
        dict for {key spec} $entries {
            option add *[lindex $spec 0] [lindex $spec 2] widgetDefault
        }
    }
    unset group entries key spec
}

oo::configurable create ::splitlayout::splitlayout {
    variable W Hull Nodes Root Serial Pending Tag Closing Owned Opaque Drag Preview Owner Handles Panels Dock Structure\
            Borders Settings
    classmethod _ruffClassHook {} {
        # Supplies class and property documentation to Ruff.
        #
        # Returns: Ruff class metadata dictionary.
        return {
            preamble {
                Configurable TclOO layout manager for Tcl/Tk 9.

                `configure` is inherited from `oo::configurable`. With no arguments it returns a dictionary
                of property names and values; with one property name it returns that value. Set properties
                with option/value pairs. Pairs are applied in order, and a failed setter leaves earlier
                successful assignments in effect. Use `configure -name` instead of `cget -name`.

                Hull properties delegate directly to the ttk frame. Layout behavior properties use oo::configurable
                directly, without option objects. Appearance dictionaries take their initial values from the Tk option
                database; see the namespace resource reference.
            }
            propertydescriptions {
                -opaqueresize {
                    Boolean enabling live sash resizing; default true. Values are normalized to 0 or 1.
                    Changing the value cancels an active deferred drag without committing its target.
                }
                -sashpreview {
                    Deferred sash preview: window, inline, or none; default window.
                    Changing the value cancels an active deferred drag. Invalid values preserve the old value.
                }
                -draghandles {
                    Boolean enabling manager-owned textless grips for every leaf; default false.
                    Drag a grip to swap at a leaf center, move at an edge, or insert at a sash. Escape or an
                    outside drop cancels. Disabling removes grips and wrappers without destroying content.
                    This setting is independent of -opaqueresize and applies to future leaves as well.
                }
                -showstructure {
                    Boolean showing an outline and inset around every split; default false. Appearance is set by -structureopts.
                    Applies to existing and future splits. Changing it cancels active gestures, preserves content,
                    and rebuilds geometry. During docking the receiving split outline is highlighted.
                }
                -dockopts {
                    Dictionary of docking preview and detection settings: -color, -linewidth, -edgewidth, -outerwidth,
                    and -threshold. Defaults come from the Tk option database. Partial updates retain other keys.
                }
                -structureopts {
                    Dictionary of split outline settings: -color, -activecolor, -borderwidth, and -padding.
                    Defaults come from the Tk option database. Partial updates retain other keys.
                }
                -sashpreviewopts {
                    Dictionary of deferred sash preview settings: -color and -width. Applies to window and inline
                    preview modes. Defaults come from the Tk option database. Partial updates retain other keys.
                }
                -width {
                    Requested hull width, delegated to the ttk frame; constructor default 800.
                }
                -height {
                    Requested hull height, delegated to the ttk frame; constructor default 600.
                }
                -padding {
                    Internal hull padding, delegated to the ttk frame.
                }
                -borderwidth {
                    Hull border width, delegated to the ttk frame.
                }
                -relief {
                    Hull relief, delegated to the ttk frame.
                }
                -cursor {
                    Hull cursor, delegated to the ttk frame.
                }
                -takefocus {
                    Hull focus traversal setting, delegated to the ttk frame.
                }
                -style {
                    Hull ttk style, delegated to the ttk frame.
                }
                -class {
                    Read-only hull class override; empty when the default ttk class is used.
                }
            }
        }
    }
    property opaqueresize -get {
        return $Opaque
    } -set {
        if {![string is boolean -strict $value]} {
            return -code error "expected boolean value but got '$value'"
        }
        set value [expr {!!$value}]
        if {![info exists Opaque] || ($value != $Opaque)} {
            my CancelDrag
            set Opaque $value
        }
    }
    property sashpreview -get {
        return $Preview
    } -set {
        if {$value ni {window inline none}} {
            return -code error {expected -sashpreview window, inline, or none}
        }
        if {![info exists Preview] || $value ne $Preview} {
            my CancelDrag
            set Preview $value
        }
    }
    property draghandles -get {
        return $Handles
    } -set {
        if {![string is boolean -strict $value]} {
            return -code error "expected boolean value but got '$value'"
        }
        set value [expr {!!$value}]
        if {![info exists Handles] || $value != $Handles} {
            my CancelDrag
            set Handles $value
            if {[info exists Root]} {
                my CaptureAll
                my Rebuild
            }
        }
    }
    property showstructure -get {
        return $Structure
    } -set {
        if {![string is boolean -strict $value]} {
            return -code error "expected boolean value but got '$value'"
        }
        set value [expr {!!$value}]
        if {![info exists Structure] || ($value != $Structure)} {
            my CancelDrag
            if {[info exists Root]} {
                my CaptureAll
            }
            set Structure $value
            if {[info exists Root]} {
                my Rebuild
            }
        }
    }
    property dockopts -get {
        return [dict get $Settings dockopts]
    } -set {
        my SetAppearance dockopts $value
    }
    property structureopts -get {
        return [dict get $Settings structureopts]
    } -set {
        my SetAppearance structureopts $value
    }
    property sashpreviewopts -get {
        return [dict get $Settings sashpreviewopts]
    } -set {
        my SetAppearance sashpreviewopts $value
    }
    method SetAppearance {group value} {
        # Validates and applies an appearance dictionary without creating option instances.
        #  group - Resource group: dockopts, structureopts, or sashpreviewopts.
        #  value - Dictionary of keys to override; unspecified keys retain current values.
        #
        # On first assignment, query the hull's option database using package-specific resource names and classes.
        # Explicit keys override database defaults before validation. Built-in defaults also survive option clear.
        # Validation completes before cancellation or mutation. Successful changes cancel gestures; structure changes
        # rebuild geometry with retained proportions. Setting unchanged values has no effect.
        # Returns: Nothing.
        set schema [dict get $::splitlayout::appearanceResources $group]
        set candidate {}
        if {[dict exists $Settings $group]} {
            set candidate [dict get $Settings $group]
        } else {
            dict for {key spec} $schema {
                lassign $spec resource type fallback
                set initial [option get $W $resource [string toupper $resource 0 0]]
                if {$initial eq {}} {
                    set initial $fallback
                }
                dict set candidate $key $initial
            }
        }
        dict for {key setting} $value {
            if {![dict exists $schema $key]} {
                return -code error "unknown -$group key '$key'"
            }
            dict set candidate $key $setting
        }
        dict for {key setting} $candidate {
            set type [lindex [dict get $schema $key] 1]
            if {$type eq {color}} {
                if {[catch {winfo rgb $W $setting}]} {
                    return -code error "invalid color for -$group $key: '$setting'"
                }
            } else {
                set minimum [expr {$type eq {positive} ? 1 : 0}]
                if {![string is entier -strict $setting] || ($setting < $minimum) ||( $setting > 2147483647)} {
                    return -code error "expected integer pixels from $minimum to 2147483647 for -$group $key"
                }
                dict set candidate $key [expr {$setting + 0}]
            }
        }
        if {[dict exists $Settings $group] && ($candidate eq [dict get $Settings $group])} {
            return
        }
        my CancelDrag
        if {($group eq {structureopts}) && [info exists Root]} {
            my CaptureAll
        }
        dict set Settings $group $candidate
        if {($group eq {structureopts}) && [info exists Root]} {
            my Rebuild
        }
        return
    }
    property width -get {
        return [$Hull cget -width]
    } -set {
        $Hull configure -width $value
    }
    property height -get {
        return [$Hull cget -height]
    } -set {
        $Hull configure -height $value
    }
    property padding -get {
        return [$Hull cget -padding]
    } -set {
        $Hull configure -padding $value
    }
    property borderwidth -get {
        return [$Hull cget -borderwidth]
    } -set {
        $Hull configure -borderwidth $value
    }
    property relief -get {
        return [$Hull cget -relief]
    } -set {
        $Hull configure -relief $value
    }
    property cursor -get {
        return [$Hull cget -cursor]
    } -set {
        $Hull configure -cursor $value
    }
    property takefocus -get {
        return [$Hull cget -takefocus]
    } -set {
        $Hull configure -takefocus $value
    }
    property style -get {
        return [$Hull cget -style]
    } -set {
        $Hull configure -style $value
    }
    property class -kind readable -get {
        return [$Hull cget -class]
    }
    self method unknown {w args} {
        # Creates a layout using Tk-style widget-path syntax.
        #  w - New widget pathname, or an unrecognized class subcommand.
        #  option - Constructor option when w is a widget pathname; otherwise an argument to the inherited handler.
        #  value - Value for the preceding constructor option.
        #
        # A name beginning with a dot creates an instance. Creation options are -width, -height, -opaqueresize,
        # -sashpreview, -showstructure, and -draghandles, with the same meanings and defaults as in the constructor.
        # Appearance dictionaries -dockopts, -structureopts, and -sashpreviewopts are also accepted.
        # Other names and their remaining arguments are delegated to the inherited unknown handler.
        #
        # Returns: The widget pathname on creation; otherwise the inherited handler result.
        # Synopsis: w ?option value ...?
        if {[string match .* $w]} {
            [self] new $w {*}$args
            return $w
        }
        next $w {*}$args
    }
    constructor {args} {
        # Creates a split layout with one empty root leaf.
        #  path - New, non-root Tk widget pathname.
        #  -width width - Nonnegative requested hull width in pixels; default 800.
        #  -height height - Nonnegative requested hull height in pixels; default 600.
        #  -opaqueresize boolean - Enable live sash resizing; default true.
        #  -sashpreview mode - Deferred preview mode: window, inline, or none; default window.
        #  -draghandles boolean - Enable textless docking grips on all leaves; default false.
        #  -showstructure boolean - Outline and inset all split regions; default false.
        #  -dockopts dictionary - Docking colors, preview line width, and detection distances; option-database defaults.
        #  -structureopts dictionary - Split outline colors, border width, and spacing; option-database defaults.
        #  -sashpreviewopts dictionary - Deferred sash preview color and width; option-database defaults.
        #
        # The hull is a ttk frame. Managed content frames and panedwindows are its immediate Tk children; their logical
        # layout hierarchy is stored separately. The object command takes the widget pathname. Existing widgets or
        # commands at that pathname, invalid sizes, and invalid options raise an error.
        #
        # Returns: Nothing.
        # Synopsis: path ?-width width? ?-height height? ?-opaqueresize boolean? ?-sashpreview mode?
        #  ?-draghandles boolean? ?-showstructure boolean? ?-dockopts dictionary?
        #  ?-structureopts dictionary? ?-sashpreviewopts dictionary?
        set Settings {}
        set Drag {}
        set Dock {}
        set Borders {}
        set Panels {}
        set Closing 0
        set Owned 0
        set Pending {}
        set Nodes {}
        set Serial 0
        set options [argparse -inline -pfirst {
            path
            {-dockopts= -default {}}
            {-structureopts= -default {}}
            {-sashpreviewopts= -default {}}
            {-width= -default 800 -type integer}
            {-height= -default 600 -type integer}
            {-showstructure= -default false -type boolean}
            {-draghandles= -default false -type boolean}
            {-opaqueresize= -default true -type boolean}
            {-sashpreview= -default window -enum {window inline none}}
        }]
        my configure -opaqueresize [dict get $options opaqueresize] -sashpreview [dict get $options sashpreview]
        my configure -showstructure [dict get $options showstructure]
        my configure -draghandles [dict get $options draghandles]
        set W [dict get $options path]
        if {![string match .* $W] || ($W eq {.})} {
            return -code error {expected a new non-root Tk widget path}
        }
        if {[winfo exists $W] || [llength [info commands ::$W]]} {
            return -code error "window or command '$W' already exists"
        }
        foreach key {width height} {
            if {[dict get $options $key] < 0} {
                return -code error "-$key must be nonnegative"
            }
        }
        set Hull [info object namespace [self]]::hull
        ttk::frame $W -width [dict get $options width] -height [dict get $options height]
        set Owned 1
        rename ::$W $Hull
        foreach group {dockopts structureopts sashpreviewopts} {
            my configure -$group [dict get $options $group]
        }
        pack propagate $W 0
        set Tag [info object namespace [self]]::bindings
        bind $Tag <Unmap> [namespace code {my CancelDock}]
        bind $Tag <Configure> [namespace code {my DockGeometry}]
        bind $Tag <Destroy> [namespace code {my HullDestroyed %W}]
        bindtags $W [linsert [bindtags $W] 0 $Tag]
        set Owner [winfo toplevel $W]
        set ownerTag ${Tag}Owner
        bind $ownerTag <Configure> [namespace code {my OwnerChanged %W}]
        bind $ownerTag <Unmap> [namespace code {my OwnerUnmapped %W}]
        bindtags $Owner [linsert [bindtags $Owner] 0 $ownerTag]
        set Root [my NewLeaf {}]
        my Rebuild
        rename [self] ::$W
    }
    destructor {
        # Destroys the layout and all of its content widgets.
        #
        # Cancels deferred dragging and pending geometry callbacks, removes the manager binding scripts and owner
        # bindtag, and destroys the owned hull. Also supports cleanup after partially completed construction.
        #
        # Returns: Nothing.
        set Closing 1
        my CancelDrag
        if {[info exists Pending]} {
            dict for {id token} $Pending {
                after cancel $token
            }
        }
        if {[info exists Tag]} {
            if {[info exists Owner] && [winfo exists $Owner]} {
                set tags [bindtags $Owner]
                set index [lsearch -exact $tags ${Tag}Owner]
                if {$index >= 0} {bindtags $Owner [lreplace $tags $index $index]}
            }
            foreach tag [list $Tag ${Tag}Sash ${Tag}Deferred ${Tag}Owner] {
                foreach event [bind $tag] {
                    bind $tag $event {}
                }
            }
        }
        if {[info exists Owned] && $Owned && [winfo exists $W]} {
            destroy $W
        }
    }
    method HullDestroyed {path} {
        # Destroys the object when its hull window is destroyed.
        #  path - Widget pathname reported by the Destroy event.
        #
        # Events for other widgets and recursive teardown are ignored.
        #
        # Returns: Nothing.
        if {$path eq $W && !$Closing} {
            my destroy
        }
    }
    method Check {id {kind {}}} {
        # Validates a logical node identifier and optional node type.
        #  id - Logical node identifier.
        #  kind - Required type, leaf or split; empty disables the type check.
        #
        # Raises an error for an unknown identifier or a mismatched type.
        #
        # Returns: The validated node identifier.
        if {![dict exists $Nodes $id]} {
            return -code error "unknown layout node '$id'"
        }
        if {($kind ne {}) && ([dict get $Nodes $id type] ne $kind)} {
            return -code error "node '$id' is not a $kind"
        }
        return $id
    }
    method Fraction {value} {
        # Validates a two-pane split fraction.
        #  value - Numeric fraction strictly between zero and one.
        #
        # Non-numeric, non-finite, and out-of-range values raise an error.
        #
        # Returns: The fraction converted to a double.
        if {![string is double -strict $value] || [catch {expr {$value > 0.0 && $value < 1.0}} valid] || !$valid} {
            return -code error {ratio must be a finite number strictly between 0 and 1}
        }
        return [expr {double($value)}]
    }
    method NewLeaf {parent {frame {}}} {
        # Allocates a leaf record and optionally creates its content frame.
        #  parent - Logical parent identifier, or empty for a root.
        #  frame - Existing content frame to reuse; empty creates a new ttk frame.
        #
        # A newly created frame is an immediate Tk child of the hull. This helper does not attach the leaf to its parent
        # or rebuild the layout.
        #
        # Returns: The new leaf identifier.
        set id n[incr Serial]
        if {$frame eq {}} {
            set frame [ttk::frame $W.content$Serial]
            bind $frame <Map> [namespace code [list my ContentMapped $frame]]
        }
        dict set Nodes $id [dict create type leaf parent $parent widget $frame]
        return $id
    }
    method root {} {
        # Returns the current logical root node.
        #
        # Returns: The root node identifier.
        return $Root
    }
    method type {id} {
        # Returns the type of a logical node.
        #  id - Existing logical node identifier.
        #
        # Returns: The string leaf or split.
        my Check $id
        return [dict get $Nodes $id type]
    }
    method parent {id} {
        # Returns the logical parent of a node.
        #  id - Existing logical node identifier.
        #
        # This relationship is independent of the actual Tk widget parent.
        #
        # Returns: The parent node identifier, or an empty string for the root.
        my Check $id
        return [dict get $Nodes $id parent]
    }
    method widget {id} {
        # Returns the widget associated with a logical node.
        #  id - Existing logical node identifier.
        #
        # Returns: The outer geometry widget: a leaf wrapper with drag handles, a split wrapper with showstructure,
        # or the content frame/native panedwindow otherwise. Use panedwindow to access a split's native widget.
        my Check $id
        if {[dict exists $Borders $id]} {return [dict get $Borders $id]}
        if {[my type $id] eq {leaf} && [dict exists $Panels $id]} {return [dict get $Panels $id pane]}
        return [dict get $Nodes $id widget]
    }
    method panedwindow {id} {
        # Returns the native panedwindow of a split, independently of structure visibility.
        #  id - Existing split identifier.
        #
        # Returns: The native ttk panedwindow pathname. Leaf identifiers raise an error.
        my Check $id split
        return [dict get $Nodes $id widget]
    }
    method frame {id} {
        # Returns the content frame of a leaf.
        #  id - Existing leaf identifier.
        #
        # Raises an error if the node is unknown or is a split.
        #
        # Returns: The leaf content frame pathname.
        my Check $id leaf
        return [dict get $Nodes $id widget]
    }
    method children {id} {
        # Returns the immediate logical children of a node.
        #  id - Existing logical node identifier.
        #
        # Returns: Child identifiers in pane order, or an empty list for a leaf.
        my Check $id
        if {[my type $id] eq {leaf}} {
            return
        }
        return [dict get $Nodes $id children]
    }
    method leaves {{id {}}} {
        # Collects the leaves below a logical node.
        #  id - Subtree root identifier; empty selects the layout root.
        #
        # Traversal follows pane order recursively. A leaf includes itself.
        #
        # Returns: A list of leaf identifiers in depth-first pane order.
        if {$id eq {}} {
            set id $Root
        }
        my Check $id
        if {[my type $id] eq {leaf}} {
            return [list $id]
        }
        set result {}
        foreach child [my children $id] {
            lappend result {*}[my leaves $child]
        }
        return $result
    }
    method node {path} {
        # Finds the logical node associated with an exact widget pathname.
        #  path - Managed content frame, pane wrapper, or panedwindow pathname.
        #
        # This method does not search ancestors; use locate for application widgets inside a content frame.
        #
        # Returns: The node identifier, or an empty string when no node matches.
        dict for {id border} $Borders {if {$border eq $path} {return $id}}
        dict for {id panel} $Panels {
            if {[dict get $panel pane] eq $path} {return $id}
        }
        dict for {id data} $Nodes {
            if {[dict get $data widget] eq $path} {
                return $id
            }
        }
        return
    }
    method locate {path} {
        # Finds the leaf containing an application widget.
        #  path - Widget pathname to locate.
        #
        # Walks the actual Tk parent chain looking for a managed content frame.
        # A split panedwindow does not identify a leaf.
        #
        # Returns: The containing leaf identifier, or empty for a missing or unrelated widget.
        if {![winfo exists $path]} {
            return
        }
        while {($path ne {}) && ($path ne $W)} {
            set id [my node $path]
            if {($id ne {}) && ([my type $id] eq {leaf})} {
                return $id
            }
            set path [winfo parent $path]
        }
        return
    }
    method container {value} {
        # Returns the geometry container for a managed node.
        #  value - Logical node identifier or exact managed widget pathname.
        #
        # The container can differ from the actual Tk parent. Unknown identifiers and unmanaged paths raise an error.
        #
        # A node identifier or wrapper path resolves to the outer geometry container. A content frame pathname
        # resolves to its pane wrapper when handles are enabled. A native panedwindow path resolves to its
        # enclosing split wrapper when showstructure is enabled.
        # Returns: The hull, parent panedwindow, or enclosing leaf/split wrapper as appropriate.
        if {[dict exists $Nodes $value]} {
            set id $value
        } else {
            set id [my node $value]
            if {$id eq {}} {
                return -code error "not a managed node or widget: '$value'"
            }
        }
        if {[dict exists $Panels $id] && $value eq [my frame $id]} {
            return [my widget $id]
        }
        if {[dict exists $Borders $id] && $value eq [my panedwindow $id]} {
            return [my widget $id]
        }
        set parent [my parent $id]
        if {$parent eq {}} {
            return $W
        }
        return [my panedwindow $parent]
    }
    method split {args} {
        # Replaces a leaf with a split containing two new leaves.
        #  node - Identifier of the existing leaf to split.
        #  -orient orientation - Split orientation: horizontal or vertical; default horizontal.
        #  -ratio fraction - First child fraction, strictly between zero and one; default 0.5.
        #  -keep child - Child receiving the existing content: first or second; default first.
        #
        # The original leaf identifier becomes the split identifier, and both child leaves receive new identifiers.
        # The retained content frame and its widget descendants are reused without reparenting or recreation. The other
        # child starts with an empty frame. Existing pane proportions are captured before rebuilding the layout.
        #
        # Returns: The two new leaf identifiers in pane order.
        # Synopsis: node ?-orient orientation? ?-ratio fraction? ?-keep child?
        set opts [argparse -inline -pfirst {
            node
            {-orient= -default horizontal -enum {horizontal vertical}}
            {-ratio= -default 0.5}
            {-keep= -default first -enum {first second}}
        }]
        set id [my Check [dict get $opts node] leaf]
        set fraction [my Fraction [dict get $opts ratio]]
        my CaptureAll
        set old [my frame $id]
        set pw [my NewSplitWidget $id [dict get $opts orient]]
        if {[dict get $opts keep] eq {first}} {
            set first [my NewLeaf $id $old]
            set second [my NewLeaf $id]
        } else {
            set first [my NewLeaf $id]
            set second [my NewLeaf $id $old]
        }
        # Detach the old content before replacing its node record.
        my Detach $old
        dict set Nodes $id [dict create type split parent [my parent $id] widget $pw \
                                    orient [dict get $opts orient] proportions [list $fraction [expr {1.0-$fraction}]]\
                                    children [list $first $second]]
        my Rebuild
        return [list $first $second]
    }
    method NewSplitWidget {id orient} {
        # Creates a panedwindow with the layout sash and lifecycle bindings.
        #  id - Logical split identifier used by geometry callbacks.
        #  orient - Panedwindow orientation: horizontal or vertical.
        #
        # Does not modify node records or attach panes. Used by split and move.
        #
        # Returns: The new panedwindow pathname.
        set pw [ttk::panedwindow $W.split[incr Serial] -orient $orient]
        # A dedicated tag AFTER the class tag captures the position after Tk's
        # sash bindings have moved it. It cannot affect application bindings.
        set motionTag ${Tag}Sash
        bind $motionTag <B1-Motion> [namespace code {my SashMoved %W}]
        bind $motionTag <ButtonRelease-1> [namespace code {my SashMoved %W}]
        set tags [bindtags $pw]
        bindtags $pw [linsert $tags 2 $motionTag]
        set deferredTag ${Tag}Deferred
        bind $deferredTag <ButtonPress-1> [namespace code {my DeferredPress %W %X %Y %x %y}]
        bind $deferredTag <B1-Motion> [namespace code {my DeferredMotion %W %X %Y}]
        bind $deferredTag <ButtonRelease-1> [namespace code {my DeferredRelease %W %X %Y}]
        bind $deferredTag <Escape> [namespace code {my DeferredEscape}]
        bind $deferredTag <Unmap> [namespace code {my CancelDrag}]
        bindtags $pw [linsert [bindtags $pw] 0 $deferredTag]
        bind $pw <Configure> [namespace code [list my SplitConfigure $id]]
        return $pw
    }
    method move {args} {
        # Moves an existing leaf to an edge or sibling position without destroying its content.
        #  leaf - Existing source leaf identifier, retained by the move.
        #  -left target - Place before a target leaf or split in a horizontal split.
        #  -right target - Place after a target leaf or split in a horizontal split.
        #  -top target - Place before a target leaf or split in a vertical split.
        #  -bottom target - Place after a target leaf or split in a vertical split.
        #  -before target - Insert before a non-root leaf or split in its existing parent.
        #  -after target - Insert after a non-root leaf or split in its existing parent.
        #
        # Exactly one destination option is required. Edge destinations reuse the target parent when its orientation
        # matches. Otherwise the target leaf becomes a split, and its existing frame moves to a newly identified leaf,
        # following split's identifier semantics. A split target is instead wrapped in a newly identified split,
        # preserving the target subtree; normal collapse may subsequently promote its sole remaining child. A split
        # target may contain the source, including the root. The source identifier, frame, widget paths, and state
        # survive.
        #
        # Within one parent and orientation, panes are reordered with their existing weights. Other moves divide the
        # target share equally between the source and target; remaining source siblings retain relative proportions.
        # A source parent left with one child is collapsed after insertion. Moving to oneself or to an already adjacent
        # position does nothing. Argument errors are detected before changing layout or cancelling a deferred drag.
        # A successful structural move cancels deferred dragging and rebuilds geometry once, without nested updates.
        #
        # Returns: The unchanged source leaf identifier. Query parent, children, or tree for the resulting structure.
        # Synopsis: leaf -left|-right|-top|-bottom|-before|-after target
        set opts [argparse -inline -pfirst {
            leaf
            {-left=}
            {-right=}
            {-top=}
            {-bottom=}
            {-before=}
            {-after=}
        }]
        set source [my Check [dict get $opts leaf] leaf]
        set destinations {}
        foreach key {left right top bottom before after} {
            if {[dict exists $opts $key]} {
                lappend destinations $key
            }
        }
        if {[llength $destinations] != 1} {
            return -code error {move requires exactly one destination: -left, -right, -top, -bottom, -before, or -after}
        }
        set where [lindex $destinations 0]
        set target [my Check [dict get $opts $where]]
        set edge [expr {$where in {left right top bottom}}]
        # A self-drop is a no-op even for the sole root leaf.
        if {$source eq $target} {
            return $source
        }
        set destination [my parent $target]
        if {!$edge && ($destination eq {})} {
            return -code error {cannot move beside root; use an edge destination}
        }
        set before [expr {$where in {left top before}}]
        set orient [expr {$where in {left right} ? {horizontal} : {vertical}}]
        set wrap [expr {$edge && (($destination eq {}) || ([dict get $Nodes $destination orient] ne $orient))}]
        set oldParent [my parent $source]
        # Reordering siblings requires neither removal nor parent collapse. Preserve weights by node.
        if {!$wrap && $oldParent eq $destination} {
            set children [my children $oldParent]
            set from [lsearch -exact $children $source]
            set reordered [lreplace $children $from $from]
            set at [lsearch -exact $reordered $target]
            if {!$before} {
                incr at
            }
            set reordered [linsert $reordered $at $source]
            if {$reordered eq $children} {
                return $source
            }
            my CancelDrag
            my CaptureAll
            set weights [dict get $Nodes $oldParent proportions]
            set share [lindex $weights $from]
            set weights [linsert [lreplace $weights $from $from] $at $share]
            dict set Nodes $oldParent children $reordered
            dict set Nodes $oldParent proportions $weights
            my Rebuild
            return $source
        }
        # Allocate any new native widget before detaching the source.
        set wrapSplit [expr {$wrap && [my type $target] eq {split}}]
        if {$wrap} {
            set wrapper $target
            if {$wrapSplit} {
                set wrapper n[incr Serial]
            }
            set pw [my NewSplitWidget $wrapper $orient]
        }
        my CancelDrag
        my CaptureAll
        my Detach [my frame $source]
        set children [my children $oldParent]
        set from [lsearch -exact $children $source]
        set remaining [lreplace $children $from $from]
        set weights [lreplace [dict get $Nodes $oldParent proportions] $from $from]
        dict set Nodes $oldParent children $remaining
        dict set Nodes $oldParent proportions [my Normalize $weights [llength $remaining]]
        if {$wrapSplit} {
            # A subtree keeps its identifier; add a new split around it and the source leaf.
            my Detach [my widget $target]
            set children [expr {$before ? [list $source $target] : [list $target $source]}]
            dict set Nodes $wrapper [dict create type split parent $destination widget $pw orient $orient\
                                             proportions {0.5 0.5} children $children]
            dict set Nodes $source parent $wrapper
            dict set Nodes $target parent $wrapper
            if {$destination eq {}} {
                set Root $wrapper
            } else {
                set children [my children $destination]
                set at [lsearch -exact $children $target]
                dict set Nodes $destination children [lreplace $children $at $at $wrapper]
            }
        } elseif {$wrap} {
            set frame [my frame $target]
            my Detach $frame
            set retained [my NewLeaf $target $frame]
            set children [expr {$before ? [list $source $retained] : [list $retained $source]}]
            dict set Nodes $target [dict create type split parent $destination widget $pw orient $orient\
                                            proportions {0.5 0.5} children $children]
            dict set Nodes $source parent $target
        } else {
            set children [my children $destination]
            set at [lsearch -exact $children $target]
            set weights [dict get $Nodes $destination proportions]
            set half [expr {[lindex $weights $at]/2.0}]
            set weights [lreplace $weights $at $at $half $half]
            if {!$before} {
                incr at
            }
            dict set Nodes $destination children [linsert $children $at $source]
            dict set Nodes $destination proportions $weights
            dict set Nodes $source parent $destination
        }
        # Delay collapse until destination links are installed, including moves beside an ancestor.
        set remaining [my children $oldParent]
        if {[llength $remaining] == 1} {
            my Promote $oldParent [lindex $remaining 0]
        }
        my Rebuild
        return $source
    }
    method insert {args} {
        # Inserts an empty leaf beside an existing non-root node.
        #  node - Identifier of the leaf or split beside which to insert a sibling.
        #  -side side - Position of the new leaf relative to node: before or after; default after.
        #
        # The new leaf shares the target parent, and the target pane share is divided equally between the two siblings.
        # Inserting beside the root raises an error; split the root first.
        #
        # Returns: The new leaf identifier.
        # Synopsis: node ?-side side?
        set opts [argparse -inline -pfirst {
            node
            {-side= -default after -enum {before after}}
        }]
        set id [my Check [dict get $opts node]]
        set parent [my parent $id]
        if {$parent eq {}} {
            return -code error {cannot insert beside root; split it first}
        }
        my CaptureAll
        set children [my children $parent]
        set index [lsearch -exact $children $id]
        set weights [dict get $Nodes $parent proportions]
        set half [expr {[lindex $weights $index]/2.0}]
        set weights [lreplace $weights $index $index $half $half]
        set new [my NewLeaf $parent]
        if {[dict get $opts side] eq {after}} {
            incr index
        }
        dict set Nodes $parent children [linsert $children $index $new]
        dict set Nodes $parent proportions $weights
        my Rebuild
        return $new
    }
    method Normalize {weights count} {
        # Normalizes a list of positive pane weights.
        #  weights - List of finite positive numeric weights.
        #  count - Required number of weights.
        #
        # Scales before summation to avoid overflow. An incorrect count, invalid weight, or range that underflows a
        # normalized weight to zero raises an error.
        #
        # Returns: Positive normalized weights whose sum is approximately one.
        if {[llength $weights]!=$count} {
            return -code error "expected $count positive weights"
        }
        set largest 0.0
        foreach value $weights {
            if {![string is double -strict $value] || [catch {expr {$value > 0.0 && $value < Inf}} valid] || !$valid} {
                return -code error {weights must be finite positive numbers}
            }
            set largest [expr {max($largest,double($value))}]
        }
        # Scale before summation to avoid overflow for large valid weights.
        set scaled [lmap value $weights {expr {double($value)/$largest}}]
        set sum 0.0
        foreach value $scaled {
            set sum [expr {$sum+$value}]
        }
        set result [lmap value $scaled {expr {$value/$sum}}]
        if {0.0 in $result} {
            return -code error  {weight range is too large to normalize}
        }
        return $result
    }
    method proportions {args} {
        # Queries or sets all pane proportions of a split.
        #  node - Identifier of an existing split.
        #  weights - Optional list containing one finite positive weight per child, in pane order. Omit to query.
        #
        # Weights are normalized before storage. Setting cancels any active deferred drag and schedules geometry
        # application at idle. A query captures current sash positions when geometry is usable and no application is
        # pending; otherwise it returns the stored proportions.
        #
        # Returns: The normalized list of pane proportions.
        # Synopsis: node ?weights?
        set opts [argparse -inline -pfirst {
            node 
            {weights -optional}
        }]
        set id [my Check [dict get $opts node] split]
        if {[dict exists $opts weights]} {
            set values [my Normalize [dict get $opts weights] [llength [my children $id]]]
            my CancelDrag
            dict set Nodes $id proportions $values
            my Schedule $id
        } else {
            my Capture $id
        }
        return [dict get $Nodes $id proportions]
    }
    method Detach {path} {
        # Removes a managed widget from its current geometry manager.
        #  path - Widget pathname to detach.
        #
        # Handles pack, grid, place, and the layout panedwindows. The widget and its descendants are neither destroyed
        # nor reparented.
        #
        # Returns: Nothing.
        set manager [winfo manager $path]
        switch -- $manager {
            pack {
                pack forget $path
            }
            grid {
                grid forget $path
            }
            place {
                place forget $path
            }
            default {
                # Native classic and themed panedwindows may use different
                # manager names across Tk versions. Query known split widgets.
                dict for {id data} $Nodes {
                    if {[dict get $data type] eq {split}} {
                        set pw [dict get $data widget]
                        if {[winfo exists $pw] && ($path in [$pw panes])} {
                            $pw forget $path
                        }
                    }
                }
            }
        }
    }
    method Rebuild {} {
        # Reattaches the logical tree and restores widget stacking.
        #
        # Cancels an active deferred drag, detaches all managed widgets, attaches the split hierarchy, and packs the
        # root into the hull. Content widgets are retained, and split geometry is scheduled for idle application.
        #
        # Returns: Nothing.
        my CancelDrag
        # Detach all known windows before adding any: this also handles swaps
        # where both frames were originally in the same panedwindow.
        dict for {id data} $Nodes {
            my Detach [dict get $data widget]
        }
        dict for {id border} $Borders {my Detach $border}
        dict for {id panel} $Panels {my Detach [dict get $panel pane]}
        my SyncPanels
        my SyncBorders
        my Attach $Root
        pack [my widget $Root] -in $W -fill both -expand 1
        my Stack $Root
    }
    method Attach {id} {
        # Recursively attaches a subtree to its panedwindows.
        #  id - Existing subtree root identifier.
        #
        # A leaf content frame is packed into its optional pane wrapper. Split children are added in logical order with
        # integer weights derived from stored proportions. Sash placement is scheduled at idle.
        #
        # Returns: Nothing.
        if {[my type $id] eq {leaf}} {
            if {[dict exists $Panels $id]} {
                pack [my frame $id] -in [my widget $id] -side top -fill both -expand 1
            }
            return
        }
        set pw [my panedwindow $id]
        if {[dict exists $Borders $id]} {
            pack $pw -in [my widget $id] -fill both -expand 1 -padx [dict get $Settings structureopts -padding]\
                -pady [dict get $Settings structureopts -padding]
        }
        foreach child [my children $id] fraction [dict get $Nodes $id proportions] {
            my Attach $child
            $pw add [my widget $child] -weight [expr {max(1,round(10000*$fraction))}]
        }
        my Schedule $id
    }
    method Stack {id} {
        # Raises managed widgets in logical ancestor-before-child order.
        #  id - Existing subtree root identifier.
        #
        # The widgets are actual Tk siblings. Raising logical children after their containers keeps content visible
        # above the panedwindows that manage it.
        #
        # Returns: Nothing.

        # Sibling windows must be above their geometry containers, including
        # content created before a later split. All are children of W.
        raise [my widget $id]
        if {[dict exists $Borders $id]} {raise [my panedwindow $id]}
        if {[dict exists $Panels $id]} {raise [my frame $id]}
        foreach child [my children $id] {
            my Stack $child
        }
    }

    method Schedule {id} {
        # Schedules one idle geometry application for a split.
        #  id - Split identifier to schedule.
        #
        # Does nothing during teardown, for a removed node, or when that node already has an idle application pending.
        #
        # Returns: Nothing.
        if {$Closing || ![dict exists $Nodes $id] || [dict exists $Pending $id]} {
            return
        }
        dict set Pending $id [after idle [namespace code [list my ApplyRatio $id]]]
    }
    method ApplyRatio {id} {
        # Applies stored split proportions to pane weights and sash positions.
        #  id - Split identifier whose idle callback is running.
        #
        # Clears the pending token and ignores removed nodes or unusable geometry. Cumulative proportions determine
        # sash positions along the split extent. Two passes accommodate native sash constraints without nested event
        # processing.
        #
        # Returns: Nothing.
        if {[dict exists $Pending $id]} {
            dict unset Pending $id
        }
        if {$Closing || ![dict exists $Nodes $id] || [my type $id] ne {split}} {
            return
        }
        set pw [my panedwindow $id]
        if {![winfo exists $pw] || ([llength [$pw panes]] < 2)} {
            return
        }
        set size [my Extent $id]
        if {$size <= 1} {
            return
        }
        set positions {}
        set sum 0.0
        foreach child [my children $id] fraction [dict get $Nodes $id proportions] {
            $pw pane [my widget $child] -weight [expr {max(1,round(10000*$fraction))}]
            set sum [expr {$sum+$fraction}]
            lappend positions [expr {round($size*$sum)}]
        }
        # Moving a sash can constrain its neighbours. Two passes establish
        # all ordered target positions regardless of the previous positions.
        set last [expr {[llength $positions]-2}]
        for {set i $last} {$i>=0} {incr i -1} {
            $pw sashpos $i [lindex $positions $i]
        }
        for {set i 0} {$i<=$last} {incr i} {
            $pw sashpos $i [lindex $positions $i]
        }
    }
    method Extent {id} {
        # Returns the size of a split along its orientation.
        #  id - Existing split identifier.
        #
        # Returns: The panedwindow width for a horizontal split, or height for a vertical split.
        if {[dict get $Nodes $id orient] eq {horizontal}} {
            return [winfo width [my panedwindow $id]]
        }
        return [winfo height [my panedwindow $id]]
    }
    method Capture {id} {
        # Stores proportions derived from the current sash positions.
        #  id - Existing split identifier.
        #
        # Capture is skipped while geometry application is pending or when the panedwindow is unmapped, too small, or
        # has an unexpected pane count. Captured shares are bounded away from zero and normalized; this helper does not
        # move sashes.
        #
        # Returns: Nothing.
        if {[dict exists $Pending $id]} {
            return
        }
        set pw [my panedwindow $id]
        set count [llength [my children $id]]
        if {[winfo ismapped $pw] && ([llength [$pw panes]] == $count) && ([my Extent $id] > 1)} {
            set weights {}
            set previous 0.0
            for {set i 0} {$i<$count-1} {incr i} {
                set position [expr {double([$pw sashpos $i])/[my Extent $id]}]
                lappend weights [expr {max(0.000001,$position-$previous)}]
                set previous $position
            }
            lappend weights [expr {max(0.000001,1.0-$previous)}]
            dict set Nodes $id proportions [my Normalize $weights $count]
        }
    }
    method CaptureAll {} {
        # Captures usable sash proportions for every split.
        #
        # Each split is subject to the pending-geometry and visibility checks performed by Capture.
        #
        # Returns: Nothing.
        dict for {id data} $Nodes {
            if {[dict get $data type] eq {split}} {
                my Capture $id
            }
        }
    }
    method SashMoved {pw} {
        # Records pane proportions after a sash gesture.
        #  pw - Panedwindow pathname reported by the sash binding.
        #
        # Ignores a pathname with no corresponding layout node. Cancels a pending geometry application before capturing
        # the resulting sash positions.
        #
        # Returns: Nothing.
        set id [my node $pw]
        if {$id eq {}} {
            return
        }
        if {[dict exists $Pending $id]} {
            after cancel [dict get $Pending $id]
            dict unset Pending $id
        }
        my Capture $id
    }
    method ratio {args} {
        # Queries or sets the first pane fraction of a two-child split.
        #  node - Identifier of a split with exactly two children.
        #  value - Optional finite first-pane fraction strictly between zero and one. Omit to query.
        #
        # Use proportions for splits with more children. Setting stores the fraction and its complement, cancels a
        # deferred drag, and schedules idle geometry application. Querying captures current geometry when possible,
        # using the same conditions as proportions.
        #
        # Returns: The stored first pane fraction.
        # Synopsis: node ?value?
        set opts [argparse -inline -pfirst {
            node 
            {value -optional}
        }]
        set id [my Check [dict get $opts node] split]
        if {[llength [my children $id]] != 2} {
            return -code error {ratio requires two children; use proportions for this split}
        }
        if {[dict exists $opts value]} {
            set fraction [my Fraction [dict get $opts value]]
            my CancelDrag
            dict set Nodes $id proportions [list $fraction [expr {1.0-$fraction}]]
            my Schedule $id
        } else {
            my Capture $id
        }
        return [lindex [dict get $Nodes $id proportions] 0]
    }
    method Drop {id} {
        # Destroys a logical subtree and all of its content.
        #  id - Existing subtree root identifier.
        #
        # Cancels deferred dragging and pending callbacks for removed nodes. This internal helper removes records and
        # widgets recursively, but does not repair the parent child list or select a new root.
        #
        # Returns: Nothing.
        my CancelDrag
        foreach child [my children $id] {
            my Drop $child
        }
        if {[dict exists $Pending $id]} {
            after cancel [dict get $Pending $id]
            dict unset Pending $id
        }
        set path [dict get $Nodes $id widget]
        if {[dict exists $Panels $id]} {
            destroy [dict get $Panels $id pane]
            dict unset Panels $id
        }
        if {[dict exists $Borders $id]} {
            destroy [dict get $Borders $id]
            dict unset Borders $id
        }
        dict unset Nodes $id
        destroy $path
    }
    method remove {id} {
        # Removes a node and all content in its subtree.
        #  id - Existing node identifier to remove.
        #
        # Removing the root behaves like clear. Otherwise, the parent retains its remaining children with normalized
        # weights. If only one child remains, that child replaces the parent split. Surviving content is preserved.
        #
        # Returns: The surviving parent split, its promoted sole child, or the new empty root.
        my Check $id
        if {$id eq $Root} {
            return [my clear]
        }
        my CaptureAll
        set parent [my parent $id]
        set children [my children $parent]
        set index [lsearch -exact $children $id]
        set children [lreplace $children $index $index]
        set weights [lreplace [dict get $Nodes $parent proportions] $index $index]
        my Drop $id
        dict set Nodes $parent children $children
        if {[llength $children] >= 2} {
            dict set Nodes $parent proportions [my Normalize $weights [llength $children]]
            my Rebuild
            return $parent
        }
        set survivor [lindex $children 0]
        my Promote $parent $survivor
        my Rebuild
        return $survivor
    }
    method Promote {parent survivor} {
        # Replaces a split with its surviving child.
        #  parent - Split identifier to remove.
        #  survivor - Child identifier to promote.
        #
        # The caller must already have removed the other children. Detaches the survivor, destroys the parent
        # panedwindow, and updates the grandparent or root link. The grandparent pane share is retained. The caller
        # rebuilds geometry afterward.
        #
        # Returns: Nothing.
        set grand [my parent $parent]
        my Detach [my widget $survivor]
        if {[dict exists $Pending $parent]} {
            after cancel [dict get $Pending $parent]
            dict unset Pending $parent
        }
        set pw [my panedwindow $parent]
        if {[dict exists $Borders $parent]} {
            destroy [dict get $Borders $parent]
            dict unset Borders $parent
        }
        dict unset Nodes $parent
        destroy $pw
        dict set Nodes $survivor parent $grand
        if {$grand eq {}} {
            set Root $survivor
        } else {
            set children [dict get $Nodes $grand children]
            set pos [lsearch -exact $children $parent]
            dict set Nodes $grand children [lreplace $children $pos $pos $survivor]
        }
    }
    method retain {id} {
        # Keeps a node while removing its siblings and collapsing its parent.
        #  id - Existing node identifier to retain.
        #
        # Destroys all sibling subtrees and their content, then promotes the retained node in place of its immediate
        # parent. Only that parent level is collapsed. Retaining the root makes no changes.
        #
        # Returns: The retained node identifier.
        my Check $id
        set parent [my parent $id]
        if {$parent eq {}} {
            return $id
        }
        my CaptureAll
        foreach sibling [my children $parent] {
            if {$sibling ne $id} {
                my Drop $sibling
            }
        }
        my Promote $parent $id
        my Rebuild
        return $id
    }
    method clear {} {
        # Destroys all layout content and creates one empty root leaf.
        #
        # Returns: The new root leaf identifier.
        my Drop $Root
        set Root [my NewLeaf {}]
        my Rebuild
        return $Root
    }
    method swap {a b} {
        # Exchanges the content frames assigned to two leaves.
        #  a - First leaf identifier.
        #  b - Second leaf identifier.
        #
        # The leaves can belong to different splits and nesting levels. Their logical positions remain unchanged, while
        # complete content frames and their existing widget state move between those positions. Actual Tk parentage and
        # widget pathnames remain unchanged. Equal identifiers do nothing.
        #
        # Returns: Nothing.
        my Check $a leaf
        my Check $b leaf
        if {$a eq $b} {
            return
        }
        my CaptureAll
        set fa [my frame $a]
        set fb [my frame $b]
        dict set Nodes $a widget $fb
        dict set Nodes $b widget $fa
        my Rebuild
        return
    }
    method tree {{id {}}} {
        # Returns a recursive snapshot of the logical layout hierarchy.
        #  id - Subtree root identifier; empty selects the layout root.
        #
        # Each node dictionary contains id, type, parent, widget, and children. With handles enabled, widget is the
        # wrapper for a leaf. Leaf dictionaries also contain the application content frame as frame,
        # with an empty children list. Split dictionaries contain orient and proportions; two-child splits also contain
        # ratio. With showstructure, widget is the enclosing split wrapper. The panedwindow field always names
        # the native split widget. Split children are nested node dictionaries in pane order.
        #
        # Proportions are refreshed from usable geometry unless application is pending.
        #
        # Returns: A nested dictionary describing the requested logical subtree.
        if {$id eq {}} {
            set id $Root
        }
        my Check $id
        set result [dict merge [dict create id $id] [dict get $Nodes $id]]
        dict set result widget [my widget $id]
        if {[my type $id] eq {leaf}} {
            dict set result frame [my frame $id]
            dict set result children {}
        } else {
            dict set result panedwindow [my panedwindow $id]
            dict set result proportions [my proportions $id]
            if {[llength [my children $id]] == 2} {
                dict set result ratio [lindex [dict get $result proportions] 0]
            }
            dict set result children [lmap child [my children $id] {my tree $child}]
        }
        return $result
    }
    method widgets {{path {}}} {
        # Returns a recursive snapshot of the actual Tk widget hierarchy.
        #  path - Widget subtree root; empty selects the layout hull.
        #
        # The pathname must exist and be the hull or one of its Tk descendants. This hierarchy includes application
        # widgets and is independent of the logical tree returned by tree.
        #
        # Returns: A nested widget dictionary with path, parent, class, manager, container, and children.
        if {$path eq {}} {
            set path $W
        }
        if {![winfo exists $path]} {
            error "bad window path name '$path'"
        }
        set ancestor $path
        while {($ancestor ne {}) && ($ancestor ne $W)} {
            set ancestor [winfo parent $ancestor]
        }
        if {$ancestor ne $W} {
            return -code error "window '$path' is outside $W"
        }
        return [my WidgetTree $path]
    }
    method WidgetTree {path} {
        # Builds a recursive Tk widget dictionary.
        #  path - Existing widget pathname to inspect.
        #
        # For managed layout nodes, container is resolved through the logical tree. For other widgets managed by pack,
        # grid, or place, it is their -in target. For other geometry managers it is empty. Children are nested
        # dictionaries in the order returned by winfo children.
        #
        # Returns: A dictionary containing path, parent, class, manager, container, and children.
        set manager [winfo manager $path]
        set container {}
        set id [my node $path]
        if {$id ne {}} {
            set container [my container $path]
        } elseif {$manager in {pack grid place}} {
            set container [dict get [$manager info $path] -in]
        }
        set result [dict create path $path parent [winfo parent $path] class [winfo class $path] manager $manager\
                            container $container]
        dict set result children [lmap child [winfo children $path] {my WidgetTree $child}]
        return $result
    }
    # Deferred mode intercepts only sash gestures, before TPanedwindow bindings.
    # Window preview uses a separate native surface. Inline preserves the old
    # child-frame preview; none provides a diagnostic/no-overlay mode. Motion
    # updates coalesce at idle. There are no nested update calls.
    method SyncBorders {} {
        # Synchronizes optional split outlines after all geometry widgets have been detached.
        #
        # Wrappers are hull children, just like native panedwindows and content frames. The configured outline width plus
        # inner spacing separates nested regions without changing widget ancestry.
        # Returns: Nothing.
        dict for {id border} $Borders {
            if {!$Structure || ![dict exists $Nodes $id] || ([my type $id] ne {split})} {
                destroy $border
                dict unset Borders $id
            }
        }
        if {!$Structure} {return}
        dict for {id data} $Nodes {
            if {([dict get $data type] ne {split}) || [dict exists $Borders $id]} {
                continue
            }
            set border [frame $W.outline[incr Serial] -borderwidth 0 -takefocus 0]
            dict set Borders $id $border
        }
        dict for {id border} $Borders {
            $border configure -highlightthickness [dict get $Settings structureopts -borderwidth]\
                -highlightbackground [dict get $Settings structureopts -color]\
                -highlightcolor [dict get $Settings structureopts -color]
        }
    }
    method HighlightSplit {target} {
        # Highlights the receiving split while retaining all other structure outlines.
        #  target - Docking destination dictionary, or empty to clear the highlight.
        #
        # A perpendicular edge move highlights the current enclosing group, which the move will subdivide.
        # Returns: Nothing.
        set receiver {}
        if {$target ne {}} {
            set id [dict get $target target]
            if {[dict get $target kind] eq {outer}} {
                set receiver $Root
            } elseif {([my type $id] eq {split}) && ([dict get $target side] ni {before after})} {
                set receiver $id
            } else {
                set receiver [my parent $id]
            }
        }
        dict for {id border} $Borders {
            if {[winfo exists $border]} {
                set color [dict get $Settings structureopts [expr {$id eq $receiver ? {-activecolor} : {-color}}]]
                $border configure -highlightbackground $color -highlightcolor $color
            }
        }
    }
    method SyncPanels {} {
        # Synchronizes optional pane wrappers with the logical leaves.
        #
        # Content must be detached before obsolete wrappers are destroyed. Wrappers belong to leaf positions;
        # application frames remain Tk children of the hull and can be packed into different wrappers after a swap.
        #
        # Returns: Nothing.
        dict for {id panel} $Panels {
            if {!$Handles || ![dict exists $Nodes $id] || ([my type $id] ne {leaf})} {
                destroy [dict get $panel pane]
                dict unset Panels $id
            }
        }
        if {!$Handles} {return}
        foreach id [my leaves] {
            if {[dict exists $Panels $id]} {
                continue
            }
            set pane [ttk::frame $W.pane[incr Serial]]
            set grip [canvas $pane.grip -height [expr {max(8,round(8*[tk scaling]))}] -borderwidth 0\
                              -highlightthickness 0 -takefocus 0 -cursor fleur]
            pack $grip -side top -fill x
            dict set Panels $id [dict create pane $pane grip $grip]
            bind $grip <Configure> [namespace code [list my DrawGrip $grip]]
            bind $grip <<ThemeChanged>> [namespace code [list my DrawGrip $grip]]
            bind $grip <ButtonPress-1> [namespace code [list my DockPress $id %X %Y]]
            bind $grip <B1-Motion> [namespace code {my DockMotion %X %Y}]
            bind $grip <ButtonRelease-1> [namespace code {my DockRelease %X %Y}]
            bind $grip <FocusOut> [namespace code {my CancelDock}]
            bind $grip <Escape> [namespace code {my DockEscape}]
            bind $grip <Unmap> [namespace code {my CancelDock}]
            bind $grip <Destroy> [namespace code {my CancelDock}]
            bind $pane <Map> [namespace code [list my PanelMapped $id]]
            bind $pane <Configure> [namespace code {my CancelDock}]
            my DrawGrip $grip
        }
    }
    method ContentMapped {path} {
        # Reapplies pane proportions when a content frame maps after handles are toggled or content is moved.
        #  path - Manager-owned application content frame pathname.
        #
        # Resolve the current node because frame ownership can change during a split or swap.
        # Returns: Nothing.
        set id [my node $path]
        if {$id ne {}} {
            my PanelMapped $id
        }
    }
    method PanelMapped {id} {
        # Reapplies proportions after a wrapper first becomes a native pane.
        #  id - Leaf identifier associated with the wrapper.
        #
        # Tk may settle new pane requests after the initial rebuild callback. Queue placement after mapping.
        # Returns: Nothing.
        if {![dict exists $Nodes $id] || ([my type $id] ne {leaf})} {
            return
        }
        set parent [my parent $id]
        if {$parent ne {}} {
            my Schedule $parent
        }
    }
    method DrawGrip {grip} {
        # Draws a small centered three-line grip using ttk theme colors.
        #  grip - Canvas pathname owned by the manager.
        #
        # Returns: Nothing.
        if {![winfo exists $grip]} {
            return
        }
        set bg [ttk::style lookup TFrame -background]
        set fg [ttk::style lookup TLabel -foreground]
        if {$bg eq {}} {
            set bg #d9d9d9
        }
        if {$fg eq {}} {
            set fg #606060
        }
        $grip configure -background $bg
        $grip delete all
        set x [expr {[winfo width $grip]/2.0}]
        set y [expr {[winfo height $grip]/2.0}]
        foreach offset {-2 0 2} {
            $grip create line [expr {$x-6}] [expr {$y+$offset}] [expr {$x+6}] [expr {$y+$offset}] -fill $fg
        }
    }
    method DockPress {id x y} {
        # Arms a leaf drag and captures pointer events with a local grab.
        #  id - Leaf whose grip was pressed.
        #  x - Pointer screen x coordinate.
        #  y - Pointer screen y coordinate.
        #
        # Existing grabs are not replaced. Focus is temporarily assigned to the grip for Escape handling.
        # Returns: Tcl break completion for an accepted press; nothing otherwise.
        if {!$Handles || ![dict exists $Panels $id] || ([grab current $W] ne {})} {
            return
        }
        my CancelDrag
        set grip [dict get $Panels $id grip]
        set previous [focus]
        grab $grip
        set Dock [dict create source $id grip $grip start [list $x $y] active 0 focus $previous target {} overlays {}\
                          geometry [my DockBounds $W]]
        focus $grip
        return -code break
    }
    method DockBounds {path} {
        # Returns a widget's screen rectangle.
        #  path - Existing widget pathname.
        #
        # Returns: Screen x, screen y, width, and height.
        return [list [winfo rootx $path] [winfo rooty $path] [winfo width $path] [winfo height $path]]
    }
    method DockGeometry {} {
        # Cancels docking if the hull moves, resizes, or becomes hidden.
        #
        # Returns: Nothing.
        if {($Dock ne {}) && (![winfo ismapped $W] || ([my DockBounds $W] ne [dict get $Dock geometry]))} {
            my CancelDock
        }
    }
    method DockOuterTarget {x y} {
        # Resolves the hull's outer rim to placement outside the entire layout region.
        #  x - Pointer screen x coordinate.
        #  y - Pointer screen y coordinate.
        #
        # Reuse a matching root split by inserting before its first or after its last child. Otherwise an edge move
        # wraps the root. The configurable outer rim is limited to one eighth of the hull size; outside points cancel.
        # Returns: A move destination dictionary, or empty if no outer destination applies.
        if {[my type $Root] ne {split}} {
            return
        }
        if {[dict get $Settings dockopts -outerwidth] == 0} {return {}}
        lassign [my DockBounds $W] px py width height
        set rx [expr {$x-$px}]
        set ry [expr {$y-$py}]
        if {($rx < 0) || ($ry < 0) || ($rx >= $width) || ($ry >= $height)} {
            return
        }
        set ex [expr {max(1,min([dict get $Settings dockopts -outerwidth],$width/8))}]
        set ey [expr {max(1,min([dict get $Settings dockopts -outerwidth],$height/8))}]
        set side {}
        set nearest 1.0
        foreach candidate {left right top bottom} distance [list [expr {double($rx)/$ex}]\
                                                                    [expr {double($width-1-$rx)/$ex}]\
                                                                    [expr {double($ry)/$ey}]\
                                                                    [expr {double($height-1-$ry)/$ey}]] {
            if {$distance < $nearest} {
                set side $candidate
                set nearest $distance
            }
        }
        if {$side eq {}} {
            return
        }
        set orient [expr {$side in {left right} ? {horizontal} : {vertical}}]
        set before [expr {$side in {left top}}]
        set target $Root
        set action $side
        if {[dict get $Nodes $Root orient] eq $orient} {
            set target [lindex [my children $Root] [expr {$before ? 0 : [llength [my children $Root]]-1}]]
            set action [expr {$before ? {before} : {after}}]
        }
        switch $side {
            left {
                set rect [list $px $py $ex $height]
            }
            right {
                set rect [list [expr {$px+$width-$ex}] $py $ex $height]
            }
            top {
                set rect [list $px $py $width $ey]
            }
            bottom {
                set rect [list $px [expr {$py+$height-$ey}] $width $ey]
            }
        }
        return [dict create op move target $target side $action kind outer rect $rect]
    }
    method DockTarget {x y} {
        # Resolves a screen coordinate to a docking operation in this manager only.
        #  x - Screen x coordinate.
        #  y - Screen y coordinate.
        #
        # The outer hull rim takes precedence, followed by native sashes and then leaf edge zones. Geometry hit testing
        # ignores the manager's preview frames; an unrelated widget covering the layout excludes the point.
        # Returns: A dictionary with operation, target, side, kind, and rectangle, or empty for no destination.
        set hit [winfo containing -displayof $W $x $y]
        while {($hit ne {}) && ($hit ne $W)} {
            set hit [winfo parent $hit]
        }
        if {$hit ne $W} {
            return
        }
        set outer [my DockOuterTarget $x $y]
        if {$outer ne {}} {
            if {[dict get $outer target] eq [dict get $Dock source]} {
                return
            }
            return $outer
        }
        dict for {id data} $Nodes {
            if {[dict get $data type] ne {split}} {
                continue
            }
            set pw [my panedwindow $id]
            if {![winfo ismapped $pw]} {
                continue
            }
            lassign [my DockBounds $pw] px py width height
            set rx [expr {$x-$px}]
            set ry [expr {$y-$py}]
            if {($rx < 0) || ($ry < 0) || ($rx >= $width) || ($ry >= $height)} {
                continue
            }
            set sash [$pw identify $rx $ry]
            if {$sash eq {}} {
                continue
            }
            set target [lindex [my children $id] [expr {$sash+1}]]
            set pos [$pw sashpos $sash]
            if {[dict get $data orient] eq {horizontal}} {
                set rect [list [expr {$px+$pos}] $py [expr {min([dict get $Settings dockopts -linewidth],$width-$pos)}] $height]
            } else {
                set rect [list $px [expr {$py+$pos}] $width [expr {min([dict get $Settings dockopts -linewidth],$height-$pos)}]]
            }
            return [dict create op move target $target side before kind sash rect $rect]
        }
        foreach id [my leaves] {
            set pane [my widget $id]
            if {![winfo ismapped $pane]} {
                continue
            }
            lassign [my DockBounds $pane] px py width height
            set rx [expr {$x-$px}]
            set ry [expr {$y-$py}]
            if {($rx < 0) || ($ry < 0) || ($rx >= $width) || ($ry >= $height)} {
                continue
            }
            if {$id eq [dict get $Dock source]} {
                return
            }
            set ex [expr {max(1,min([dict get $Settings dockopts -edgewidth],$width/4))}]
            set ey [expr {max(1,min([dict get $Settings dockopts -edgewidth],$height/4))}]
            set side {}
            set nearest 2.0
            foreach candidate {left right top bottom} distance [list [expr {double($rx)/$ex}]\
                                                                        [expr {double($width-1-$rx)/$ex}]\
                                                                        [expr {double($ry)/$ey}]\
                                                                        [expr {double($height-1-$ry)/$ey}]] {
                if {[dict get $Settings dockopts -edgewidth] > 0 && ($distance < 1.0) && ($distance < $nearest)} {
                    set side $candidate
                    set nearest $distance
                }
            }
            set rect [list $px $py $width $height]
            if {$side eq {}} {
                return [dict create op swap target $id side {} kind center rect $rect]
            }
            switch $side {
                left {
                    set rect [list $px $py $ex $height]
                }
                right {
                    set rect [list [expr {$px+$width-$ex}] $py $ex $height]
                }
                top {
                    set rect [list $px $py $width $ey]
                }
                bottom {
                    set rect [list $px [expr {$py+$height-$ey}] $width $ey]
                }
            }
            return [dict create op move target $id side $side kind edge rect $rect]
        }
        return
    }
    method DockMotion {x y} {
        # Updates drag activation, destination, and the lightweight placement preview.
        #  x - Pointer screen x coordinate.
        #  y - Pointer screen y coordinate.
        #
        # The dockopts threshold distinguishes clicks from drags. No layout changes happen here.
        # Returns: Tcl break completion during a gesture; nothing otherwise.
        if {$Dock eq {}} {
            return
        }
        if {[grab current $W] ne [dict get $Dock grip]} {
            my CancelDock
            return
        }
        if {![dict get $Dock active]} {
            lassign [dict get $Dock start] sx sy
            if {max(abs($x-$sx),abs($y-$sy)) < [dict get $Settings dockopts -threshold]} {
                return -code break
            }
            dict set Dock active 1
        }
        set target [my DockTarget $x $y]
        if {$target ne [dict get $Dock target]} {
            dict set Dock target $target
            my DockPreview
        }
        return -code break
    }
    method DockPreview {} {
        # Draws an outline for a swap, an edge band for an edge move, or an insertion line for a sash.
        #
        # Four reusable hull-child frames avoid changing application geometry or creating a new toplevel.
        # Returns: Nothing.
        set overlays [dict get $Dock overlays]
        if {$overlays eq {}} {
            for {set i 0} {$i < 4} {incr i} {
                lappend overlays [frame $W.drop[incr Serial] -background [dict get $Settings dockopts -color]\
                                          -borderwidth 0 -takefocus 0]
            }
            dict set Dock overlays $overlays
        }
        foreach path $overlays {place forget $path}
        set target [dict get $Dock target]
        my HighlightSplit $target
        if {$target eq {}} {
            return
        }
        lassign [dict get $target rect] x y width height
        set x [expr {$x-[winfo rootx $W]}]
        set y [expr {$y-[winfo rooty $W]}]
        if {[dict get $target kind] eq {center}} {
            set t [expr {min([dict get $Settings dockopts -linewidth],$width,$height)}]
            set boxes [list [list $x $y $width $t] [list $x [expr {$y+$height-$t}] $width $t] [list $x $y $t $height]\
                               [list [expr {$x+$width-$t}] $y $t $height]]
        } else {
            set boxes [list [list $x $y $width $height]]
        }
        foreach path $overlays box $boxes {
            if {$box eq {}} {
                continue
            }
            lassign $box x y width height
            place $path -x $x -y $y -width $width -height $height
            raise $path
        }
    }
    method DockRelease {x y} {
        # Commits one accepted drop using swap or move, then releases all gesture resources.
        #  x - Release screen x coordinate.
        #  y - Release screen y coordinate.
        #
        # Releases without an activated drag or valid same-manager destination are cancellations.
        # Returns: Tcl break completion during a gesture; nothing otherwise.
        if {$Dock eq {}} {
            return
        }
        set source [dict get $Dock source]
        set target {}
        if {[dict get $Dock active] && ([grab current $W] eq [dict get $Dock grip])} {
            set target [my DockTarget $x $y]
        }
        my CancelDock
        if {$target ne {}} {
            if {[dict get $target op] eq {swap}} {
                my swap $source [dict get $target target]
            } else {
                my move $source -[dict get $target side] [dict get $target target]
            }
        }
        return -code break
    }
    method DockEscape {} {
        # Cancels an armed or active content drag without changing the layout.
        #
        # Returns: Tcl break completion when cancelled; nothing otherwise.
        if {$Dock eq {}} {
            return
        }
        my CancelDock
        return -code break
    }
    method CancelDock {} {
        # Removes a docking preview and releases only the grab and focus owned by this gesture.
        #
        # Safe during partial construction, widget destruction, and repeated cleanup. No drop is committed.
        # Returns: Nothing.
        if {![info exists Dock] || ($Dock eq {})} {
            return
        }
        my HighlightSplit {}
        set state $Dock
        set Dock {}
        set grip [dict get $state grip]
        if {[winfo exists $grip] && ([grab current $grip] eq $grip)} {
            grab release $grip
        }
        foreach path [dict get $state overlays] {
            if {[winfo exists $path]} {
                destroy $path
            }
        }
        set previous [dict get $state focus]
        if {!$Closing && ([focus] eq $grip) && ($previous ne {}) && [winfo exists $previous]} {
            focus $previous
        }
    }
    # Deferred sash mode intercepts gestures before TPanedwindow bindings.
    # Its preview mode is independent of the docking preview.
    method DeferredPress {pw rootX rootY x y} {
        # Starts a deferred sash gesture when live resizing is disabled.
        #  pw - Panedwindow receiving the button press.
        #  rootX - Pointer x coordinate in screen coordinates.
        #  rootY - Pointer y coordinate in screen coordinates.
        #  x - Pointer x coordinate relative to the panedwindow.
        #  y - Pointer y coordinate relative to the panedwindow.
        #
        # Runs before the native panedwindow class binding. Non-sash presses and live-resize mode pass through. An
        # accepted gesture applies any pending proportions, records the initial sash and focus state, and creates the
        # configured preview surface without resizing content.
        #
        # Returns: Nothing for a pass-through event; Tcl break completion for an accepted gesture.
        if {$Opaque} {
            return
        }
        my CancelDrag
        set sash [$pw identify sash $x $y]
        if {$sash eq {}} {
            return
        }
        set id [my node $pw]
        if {$id eq {}} {
            return
        }
        if {[dict exists $Pending $id]} {
            after cancel [dict get $Pending $id]
            my ApplyRatio $id
        }
        set orient [$pw cget -orient]
        set coordinate [expr {$orient eq {horizontal} ? $rootX : $rootY}]
        set proxy {}
        if {$Preview ne {none}} {
            set proxy $W.proxy[incr Serial]
            if {$Preview eq {window}} {
                toplevel $proxy -background [dict get $Settings sashpreviewopts -color] -borderwidth 0 -takefocus 0
                wm withdraw $proxy
                wm overrideredirect $proxy 1
                wm transient $proxy $Owner
                wm resizable $proxy 0 0
            } else {
                frame $proxy -background [dict get $Settings sashpreviewopts -color] -borderwidth 1 -relief raised\
                        -takefocus 0
            }
        }
        set Drag [dict create pw $pw id $id sash $sash orient $orient start $coordinate position [$pw sashpos $sash]\
                          target [$pw sashpos $sash] proxy $proxy focus [focus] previewAfter {} shownGeometry {}\
                          rootPosition [list [winfo rootx $pw] [winfo rooty $pw]]]
        focus $pw
        my ShowProxy
        return -code break
    }
    method DeferredMotion {pw rootX rootY} {
        # Handles pointer motion for an active deferred sash gesture.
        #  pw - Panedwindow receiving the motion event.
        #  rootX - Pointer x coordinate in screen coordinates.
        #  rootY - Pointer y coordinate in screen coordinates.
        #
        # Only a gesture belonging to this panedwindow updates the preview target.
        #
        # Returns: Nothing for an unrelated event; Tcl break completion for handled motion.
        if {($Drag eq {}) || ([dict get $Drag pw] ne $pw)} {
            return
        }
        my MoveProxy $rootX $rootY
        return -code break
    }
    method MoveProxy {rootX rootY {show 1}} {
        # Updates the target position for an active deferred gesture.
        #  rootX - Current pointer x coordinate in screen coordinates.
        #  rootY - Current pointer y coordinate in screen coordinates.
        #  show - Whether to schedule a preview refresh; defaults to 1.
        #
        # Computes movement relative to the initial pointer position, constrains the target between neighboring sashes
        # and the split bounds, and coalesces preview updates at idle. A false show value samples the release position
        # without scheduling another preview refresh. Requires an active gesture.
        #
        # Returns: Nothing.
        set pw [dict get $Drag pw]
        set sash [dict get $Drag sash]
        set coordinate [expr {[dict get $Drag orient] eq {horizontal} ? $rootX : $rootY}]
        set target [expr {[dict get $Drag position]+$coordinate-[dict get $Drag start]}]
        set lower 0
        set upper [my Extent [dict get $Drag id]]
        if {$sash > 0} {
            set lower [$pw sashpos [expr {$sash-1}]]
        }
        if {$sash < [llength [$pw panes]]-2} {
            set upper [$pw sashpos [expr {$sash+1}]]
        }
        dict set Drag target [expr {max($lower,min($upper,$target))}]
        if {$show && ([dict get $Drag proxy] ne {}) && ([dict get $Drag previewAfter] eq {})} {
            dict set Drag previewAfter [after idle [namespace code {my ShowProxy}]]
        }
    }
    method ShowProxy {} {
        # Displays the deferred sash preview at its latest target.
        #
        # Clears the preview idle token. The none mode creates no visual surface. The window mode positions a separate
        # toplevel; inline places a frame relative to the hull. The configurable-width marker is constrained to the
        # split bounds, and unchanged geometry is skipped. Content panes are not resized.
        #
        # Returns: Nothing.
        if {$Drag eq {}} {
            return
        }
        dict set Drag previewAfter {}
        set proxy [dict get $Drag proxy]
        if {$proxy eq {}} {
            return
        }
        set pw [dict get $Drag pw]
        set x [winfo rootx $pw]
        set y [winfo rooty $pw]
        set position [dict get $Drag target]
        set width [winfo width $pw]
        set height [winfo height $pw]
        set thickness [dict get $Settings sashpreviewopts -width]
        if {[dict get $Drag orient] eq {horizontal}} {
            set x [expr {$x+max(0,min($width-$thickness,$position))}]
            set width [expr {min($thickness,$width)}]
        } else {
            set y [expr {$y+max(0,min($height-$thickness,$position))}]
            set height [expr {min($thickness,$height)}]
        }
        set geometry [list $x $y $width $height]
        if {$geometry eq [dict get $Drag shownGeometry]} {
            return
        }
        dict set Drag shownGeometry $geometry
        if {$Preview eq {window}} {
            # Explicit '+' keeps negative root coordinates absolute, including
            # monitors to the left of or above the primary display.
            wm geometry $proxy ${width}x${height}+${x}+${y}
            if {[wm state $proxy] eq {withdrawn}} {
                wm deiconify $proxy
                raise $proxy
            }
        } else {
            place $proxy -x [expr {$x-[winfo rootx $W]}] -y [expr {$y-[winfo rooty $W]}] -width $width -height $height
            raise $proxy
        }
    }
    method DeferredRelease {pw rootX rootY} {
        # Commits the final position of a deferred sash gesture.
        #  pw - Panedwindow receiving the button release.
        #  rootX - Pointer x coordinate in screen coordinates.
        #  rootY - Pointer y coordinate in screen coordinates.
        #
        # Samples the release position, moves the native sash, and captures the resulting proportions. Cleanup runs even
        # if sash placement fails. Actual layout work is requested before the preview is destroyed.
        #
        # Returns: Nothing for an unrelated event; Tcl break completion for a handled release.
        if {($Drag eq {}) || ([dict get $Drag pw] ne $pw)} {
            return
        }
        # Sample the release coordinate without moving a soon-to-be-deleted
        # preview. Queue layout before preview removal generates exposure work.
        my MoveProxy $rootX $rootY 0
        set sash [dict get $Drag sash]
        set target [dict get $Drag target]
        try {
            $pw sashpos $sash $target
            my SashMoved $pw
        } finally {
            my CancelDrag
        }
        return -code break
    }
    method DeferredEscape {} {
        # Cancels a deferred sash gesture in response to Escape.
        #
        # Discards the preview target without committing it to the native sash.
        #
        # Returns: Nothing without an active gesture; Tcl break completion after cancellation.
        if {$Drag eq {}} {
            return
        }
        my CancelDrag
        return -code break
    }
    method CancelDrag {} {
        # Cancels deferred dragging and removes its preview resources.
        #
        # Clears gesture state, cancels a queued preview callback, and destroys the preview widget. Restores the
        # previous focus when it still exists, focus remains on the dragged panedwindow, and teardown is not underway.
        # The target sash position is not committed. Safe without an active gesture.
        #
        # Returns: Nothing.
        my CancelDock
        if {![info exists Drag] || ($Drag eq {})} {
            return
        }
        set drag $Drag
        set Drag {}
        if {[dict get $drag previewAfter] ne {}} {
            after cancel [dict get $drag previewAfter]
        }
        set proxy [dict get $drag proxy]
        if {($proxy ne {}) && [winfo exists $proxy]} {
            destroy $proxy
        }
        set oldFocus [dict get $drag focus]
        if {!$Closing && ([focus] eq [dict get $drag pw]) && ($oldFocus ne {}) && [winfo exists $oldFocus]} {
            focus $oldFocus
        }
    }
    method SplitConfigure {id} {
        # Handles a split geometry change.
        #  id - Split identifier reported by the Configure binding.
        #
        # Cancels a deferred gesture because its saved coordinates may be stale, then schedules application of the
        # split and ancestor proportions. Nested requests can change ancestor sashes without resizing their windows.
        #
        # Returns: Nothing.

        my CancelDock
        # An external resize/move invalidates preview coordinates. Cancel the
        # preview and let the normal ratio handler process the new geometry.
        if {$Drag ne {}} {
            my CancelDrag
        }
        my Schedule $id
        # A nested split can change its parent's sash allocation through a geometry request without changing
        # the parent's outer size. Reapply ancestor proportions even when no parent Configure event is emitted.
        if {[dict exists $Nodes $id]} {
            set parent [my parent $id]
            while {$parent ne {}} {
                my Schedule $parent
                set parent [my parent $parent]
            }
        }
    }
    method OwnerChanged {path} {
        # Cancels deferred dragging when the owner moves the split.
        #  path - Widget pathname reported by the owner Configure event.
        #
        # For an active gesture on the owner toplevel, compares the current split screen position with the saved
        # position. A change invalidates the drag.
        #
        # Returns: Nothing.
        if {$path eq $Owner} {my DockGeometry}
        if {($path ne $Owner) || ($Drag eq {})} {
            return
        }
        set pw [dict get $Drag pw]
        if {[list [winfo rootx $pw] [winfo rooty $pw]] ne [dict get $Drag rootPosition]} {
            my CancelDrag
        }
    }
    method OwnerUnmapped {path} {
        # Cancels deferred dragging when the owner is unmapped.
        #  path - Widget pathname reported by the Unmap event.
        #
        # Events whose pathname does not match the owner toplevel are ignored.
        #
        # Returns: Nothing.
        if {$path eq $Owner} {
            my CancelDrag
        }
    }

}

namespace eval splitlayout {
    namespace export splitlayout
}
