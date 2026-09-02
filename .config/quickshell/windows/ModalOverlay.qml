import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

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
    property bool closeOnClickOutside: false
    property int cardWidth: 480
    property int padding: 16
    property int spacing: 12
    property Item focusItem: null

    // When set, the card hangs below this item and is right-aligned to it
    // rather than centred. The item lives in another window, but every layer
    // surface here shares the screen's origin, so its mapped position needs no
    // translation.
    property Item anchorItem: null

    readonly property bool anchored: root.anchorItem !== null

    property real anchorX: 0
    property real anchorY: 0

    function reanchor(): void {
        if (!root.anchored)
            return;

        const pos = root.anchorItem.mapToItem(null, 0, 0);
        root.anchorX = pos.x + root.anchorItem.width;
        root.anchorY = pos.y + root.anchorItem.height;
    }

    signal opened
    signal dismissed

    screen: FocusedScreen.screen
    color: root.dim ? Theme.overlayScrim : "transparent"

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

    MouseArea {
        anchors.fill: parent

        onClicked: {
            if (root.closeOnClickOutside)
                root.dismissed();
        }
    }

    Rectangle {
        id: card

        x: root.anchored ? Math.max(0, root.anchorX - width) : (parent.width - width) / 2
        y: root.anchored ? root.anchorY : (parent.height - height) / 2
        width: root.cardWidth
        implicitHeight: body.implicitHeight + root.padding * 2
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        border.width: 1
        radius: 6

        // The card holds focus itself so Escape lands even when there is no
        // focusItem to take it -- a bar popup has no field to type into.
        // Where there is one, focus moves to that child and Escape still
        // bubbles back up through here.
        focus: true

        Keys.onEscapePressed: root.dismissed()

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
