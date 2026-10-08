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

    variable _ruff_preamble {}
}

oo::configurable create ::splitlayout::splitlayout {
    variable W Hull Nodes Root Serial Pending Tag Closing Owned Opaque Drag Preview Owner
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

                Hull properties delegate directly to the ttk frame. No option objects or option-database
                resources are created for the layout properties.
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
        # and -sashpreview, with the same meanings and defaults as in the constructor. Other names and their
        # remaining arguments are delegated to the inherited unknown handler.
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
        #
        # The hull is a ttk frame. Managed content frames and panedwindows are its immediate Tk children; their logical
        # layout hierarchy is stored separately. The object command takes the widget pathname. Existing widgets or
        # commands at that pathname, invalid sizes, and invalid options raise an error.
        #
        # Returns: Nothing.
        # Synopsis: path ?-width width? ?-height height? ?-opaqueresize boolean? ?-sashpreview mode?
        set Drag {}
        set Closing 0
        set Owned 0
        set Pending {}
        set Nodes {}
        set Serial 0
        set options [argparse -inline -pfirst {
            path
            {-width= -default 800 -type integer}
            {-height= -default 600 -type integer}
            {-opaqueresize= -default true -type boolean}
            {-sashpreview= -default window -enum {window inline none}}
        }]
        my configure -opaqueresize [dict get $options opaqueresize] -sashpreview [dict get $options sashpreview]
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
        pack propagate $W 0
        set Tag [info object namespace [self]]::bindings
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
        # Returns: The content frame pathname for a leaf, or panedwindow pathname for a split.
        my Check $id
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
        return [my widget $id]
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
        #  path - Managed content frame or panedwindow pathname.
        #
        # This method does not search ancestors; use locate for application widgets inside a content frame.
        #
        # Returns: The node identifier, or an empty string when no node matches.
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
        # Returns: The hull for the root, or the logical parent panedwindow for another node.
        if {[dict exists $Nodes $value]} {
            set id $value
        } else {
            set id [my node $value]
            if {$id eq {}} {
                return -code error "not a managed node or widget: '$value'"
            }
        }
        set parent [my parent $id]
        if {$parent eq {}} {
            return $W
        }
        return [my widget $parent]
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
        #  -left target - Place before a target leaf in a horizontal split.
        #  -right target - Place after a target leaf in a horizontal split.
        #  -top target - Place before a target leaf in a vertical split.
        #  -bottom target - Place after a target leaf in a vertical split.
        #  -before target - Insert before a non-root leaf or split in its existing parent.
        #  -after target - Insert after a non-root leaf or split in its existing parent.
        #
        # Exactly one destination option is required. Edge destinations reuse the target parent when its orientation
        # matches. Otherwise the target leaf becomes a split, and its existing frame moves to a newly identified leaf,
        # following split's identifier semantics. The source identifier, frame, widget paths, and state survive.
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
        if {$edge} {
            my Check $target leaf
        }
        # A self-drop is a no-op even for the sole root leaf.
        if {$source eq $target} {
            return $source
        }
        set destination [my parent $target]
        if {!$edge && ($destination eq {})} {
            return -code error {cannot move beside root; use an edge destination on a leaf}
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
        if {$wrap} {
            set pw [my NewSplitWidget $target $orient]
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
        if {$wrap} {
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
        my Attach $Root
        pack [my widget $Root] -in $W -fill both -expand 1
        my Stack $Root
    }
    method Attach {id} {
        # Recursively attaches a subtree to its panedwindows.
        #  id - Existing subtree root identifier.
        #
        # Leaves need no attachment work here. Split children are added in logical order with integer weights derived
        # from stored proportions. Sash placement is scheduled at idle.
        #
        # Returns: Nothing.
        if {[my type $id] eq {leaf}} {
            return
        }
        set pw [my widget $id]
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
        set pw [my widget $id]
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
            return [winfo width [my widget $id]]
        }
        return [winfo height [my widget $id]]
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
        set pw [my widget $id]
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
        set path [my widget $id]
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
        set pw [my widget $parent]
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
        # Each node dictionary contains id, type, parent, widget, and children. Leaf dictionaries also contain frame,
        # with an empty children list. Split dictionaries contain orient and proportions; two-child splits also contain
        # ratio. Split children are nested node dictionaries in pane order.
        #
        # Proportions are refreshed from usable geometry unless application is pending.
        #
        # Returns: A nested dictionary describing the requested logical subtree.
        if {$id eq {}} {
            set id $Root
        }
        my Check $id
        set result [dict merge [dict create id $id] [dict get $Nodes $id]]
        if {[my type $id] eq {leaf}} {
            dict set result frame [my frame $id]
            dict set result children {}
        } else {
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
            set container [my container $id]
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
                toplevel $proxy -background #606060 -borderwidth 0 -takefocus 0
                wm withdraw $proxy
                wm overrideredirect $proxy 1
                wm transient $proxy $Owner
                wm resizable $proxy 0 0
            } else {
                frame $proxy -background #606060 -borderwidth 1 -relief raised -takefocus 0
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
        # toplevel; inline places a frame relative to the hull. The three-pixel marker is constrained to the split
        # bounds, and unchanged geometry is skipped. Content panes are not resized.
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
        if {[dict get $Drag orient] eq {horizontal}} {
            set x [expr {$x+max(0,min($width-3,$position))}]
            set width [expr {min(3,$width)}]
        } else {
            set y [expr {$y+max(0,min($height-3,$position))}]
            set height [expr {min(3,$height)}]
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
        # Cancels a deferred gesture because its saved coordinates may be stale, then schedules application of the split
        # proportions.
        #
        # Returns: Nothing.

        # An external resize/move invalidates preview coordinates. Cancel the
        # preview and let the normal ratio handler process the new geometry.
        if {$Drag ne {}} {
            my CancelDrag
        }
        my Schedule $id
    }
    method OwnerChanged {path} {
        # Cancels deferred dragging when the owner moves the split.
        #  path - Widget pathname reported by the owner Configure event.
        #
        # For an active gesture on the owner toplevel, compares the current split screen position with the saved
        # position. A change invalidates the drag.
        #
        # Returns: Nothing.
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
