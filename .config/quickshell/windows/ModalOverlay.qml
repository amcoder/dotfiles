import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// A centred card on an overlay layer surface with exclusive keyboard focus,
// drawn on the focused output. Children go into the card's column.
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

    onVisibleChanged: {
        if (!root.visible)
            return;

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
        anchors.centerIn: parent
        width: root.cardWidth
        implicitHeight: body.implicitHeight + root.padding * 2
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        border.width: 1
        radius: 6

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
