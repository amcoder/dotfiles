import QtQuick
import Quickshell
import qs.config

// The anchored card a bar item drops down. Children stack in a column inside
// `padding`, and the popup sizes itself to them unless the caller overrides
// implicitHeight. Clicking outside breaks the compositor's popup grab, which
// hides it; Escape does the same from the keyboard.
//
// The size is taken when the popup maps and never again: `height` follows
// `implicitHeight` at that moment and then diverges, and `reposition()` does
// not re-send it. Content that grows while the popup is open is clipped, so a
// panel that would grow on its own has to reserve the space or stay out.
PopupWindow {
    id: root

    default property alias content: column.data

    property Item anchorItem: null
    property int padding: 12
    property int spacing: 12

    function toggle(): void {
        root.visible = !root.visible;
    }

    anchor.item: root.anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left

    implicitWidth: 360
    implicitHeight: column.implicitHeight + 2 * root.padding
    color: "transparent"
    visible: false
    grabFocus: true

    Rectangle {
        anchors.fill: parent
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        border.width: 1
        radius: 6

        focus: true
        Keys.onEscapePressed: root.visible = false

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.padding
            spacing: root.spacing
        }
    }
}
