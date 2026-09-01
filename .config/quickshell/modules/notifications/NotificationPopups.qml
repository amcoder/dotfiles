import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The transient stack, on whichever output holds the focused workspace --
// matching dunst's `follow = keyboard`. Click-through outside the cards.
PanelWindow {
    id: root

    readonly property int cardSpacing: 8
    readonly property int maxCards: 5

    readonly property var shown: NotificationService.popups.slice(0, root.maxCards)
    readonly property int hidden: NotificationService.popups.length - root.shown.length

    screen: FocusedScreen.screen
    visible: NotificationService.popups.length > 0
    color: "transparent"
    focusable: false

    anchors.bottom: true
    anchors.right: true
    margins.bottom: 24
    margins.right: 24

    implicitWidth: 400
    implicitHeight: Math.max(1, stack.implicitHeight)
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    mask: Region {
        item: stack
    }

    HoverHandler {
        id: hover
    }

    Binding {
        target: NotificationService
        property: "popupsHovered"
        value: hover.hovered
    }

    Column {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: root.cardSpacing

        Repeater {
            model: root.shown

            NotificationCard {
                required property var modelData

                width: stack.width
                entry: modelData

                onDismissed: NotificationService.dismiss(modelData)
            }
        }

        Rectangle {
            width: stack.width
            visible: root.hidden > 0
            implicitHeight: 28
            radius: 10
            color: Theme.popupBackground
            border.color: Theme.popupBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.hidden === 1 ? "1 more notification" : `${root.hidden} more notifications`
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }
    }
}
