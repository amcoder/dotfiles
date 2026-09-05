import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// A card on an overlay layer surface with exclusive keyboard focus, centred on
// the focused output or hung under `anchorItem` when one is given. Children go
// into the card's column.
//
// `keyboardFocus` is deliberately a constant: Quickshell applies it when the
// layer surface is created and ignores every later change, so a surface that
// wants the keyboard some of the time toggles `visible` -- which destroys and
// recreates the surface -- rather than the property.
PanelWindow {
    id: root

    default property alias content: body.data

    required property string namespaceSuffix

    // Whether the surface behind the card is scrimmed or fully transparent.
    property bool dim: true

    // Whether the card and the scrim are painted at all. A surface that is
    // mapped but not drawn is how the window cycler catches the Super release
    // during a tap of Super+Tab, which has to switch windows without anything
    // appearing on screen; while it is undrawn the surface is click-through
    // too, so it cannot swallow a pointer event meant for what is beneath it.
    property bool drawn: true
    property bool closeOnClickOutside: false
    property int cardWidth: 480

    // The card's fill. An attached card takes the colour of the surface it
    // hangs from instead, so the two read as one shape.
    property color cardColor: Theme.popupBackground

    property int padding: 16
    property int spacing: 12
    property Item focusItem: null

    // When set, the card hangs below this item, centred on it rather than on
    // the screen. The item lives in another window, but every layer surface
    // here shares the screen's origin, so its mapped position needs no
    // translation.
    property Item anchorItem: null

    readonly property bool anchored: root.anchorItem !== null

    // Draws the card as a continuation of the surface above it instead of a
    // box floating under it: no top border, and top corners that curve the
    // other way so the sides flare out of the bar's bottom edge. An attached
    // card also opens and closes by growing downward.
    property bool attached: false

    property int cornerRadius: 6

    // How far the flared top corners reach past the card on either side.
    property int flare: 10

    property int revealDuration: 160

    // Drives the expand/collapse of an attached card.
    //
    // `cardHeight` is what the owner keeps the surface mapped by: it is still
    // the full height at the instant `revealed` goes false and only reaches
    // zero once the card has finished rolling up. Watching the animation's
    // `running` instead loses the race -- a `visible` binding re-evaluated
    // before the Behavior has started reads false and unmaps the surface
    // mid-collapse, which the layer surface shows as a flicker.
    property bool revealed: true

    readonly property real cardHeight: card.height

    property real anchorX: 0
    property real anchorY: 0

    function reanchor(): void {
        if (!root.anchored)
            return;

        const pos = root.anchorItem.mapToItem(null, 0, 0);
        root.anchorX = pos.x + root.anchorItem.width / 2;
        root.anchorY = pos.y + root.anchorItem.height;
    }

    signal opened
    signal dismissed

    screen: FocusedScreen.screen
    color: root.dim && root.drawn ? Theme.overlayScrim : "transparent"

    mask: root.drawn ? null : blank

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: `quickshell-${root.namespaceSuffix}`

    // Re-measured on every open: bar items shift as their neighbours change
    // width, so a position taken once at startup goes stale.
    onVisibleChanged: {
        if (!root.visible)
            return;

        root.reanchor();
        root.opened();

        if (root.focusItem !== null)
            root.focusItem.forceActiveFocus();
    }

    Region {
        id: blank
    }

    MouseArea {
        anchors.fill: parent

        onClicked: {
            if (root.closeOnClickOutside)
                root.dismissed();
        }
    }

    Item {
        id: card

        visible: root.drawn

        // The flare needs room on both sides, so an anchored card stops short
        // of the screen edge by that much.
        x: {
            if (!root.anchored)
                return (parent.width - width) / 2;

            const inset = root.attached ? root.flare : 0;
            return Math.max(inset, Math.min(root.anchorX - width / 2, parent.width - width - inset));
        }
        y: root.anchored ? root.anchorY : (parent.height - height) / 2
        width: root.cardWidth
        implicitHeight: body.implicitHeight + root.padding * 2
        height: root.revealed ? implicitHeight : 0

        Behavior on height {
            enabled: root.attached

            NumberAnimation {
                duration: root.revealDuration
                easing.type: Easing.OutCubic
            }
        }

        // The card holds focus itself so Escape lands even when there is no
        // focusItem to take it -- a bar popup has no field to type into.
        // Where there is one, focus moves to that child and Escape still
        // bubbles back up through here.
        focus: true

        Keys.onEscapePressed: root.dismissed()

        Rectangle {
            anchors.fill: parent
            visible: !root.attached
            color: root.cardColor
            border.color: Theme.popupBorder
            border.width: 1
            radius: root.cornerRadius
        }

        AttachedOutline {
            visible: root.attached && card.height > 0
            fillColor: root.cardColor
            cornerRadius: root.cornerRadius
            flare: root.flare
        }

        // Clipped here rather than on the card, which the flare overflows by
        // design.
        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.padding
                spacing: root.spacing
            }
        }
    }
}
