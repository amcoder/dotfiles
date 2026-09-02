import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The transient stack, hung under the bar's bell on whichever output holds the
// focused workspace -- matching dunst's `follow = keyboard`, which is what the
// focused-screen gate reproduces now that there is one of these per bar.
//
// Not a BarPopup, and it cannot be one: a ModalOverlay takes exclusive
// keyboard focus and covers the screen with a click-catcher, so every arriving
// notification would steal the keyboard and swallow the next click. This holds
// no focus at all and masks its input region down to the card. It borrows only
// the look, through AttachedOutline.
PanelWindow {
    id: root

    required property Item anchorItem

    readonly property int maxCards: 5
    readonly property int padding: 12
    readonly property int revealDuration: 160

    readonly property var shown: NotificationService.popups.slice(0, root.maxCards)
    readonly property int hidden: NotificationService.popups.length - root.shown.length

    // The bar's own screen, read from the anchor rather than from `screen`:
    // Quickshell resolves a window's screen as it maps, so a `present` that
    // read it would loop back through `visible`.
    readonly property var barScreen: root.anchorItem?.QsWindow.window?.screen ?? null

    readonly property bool present: root.barScreen === FocusedScreen.screen && NotificationService.popups.length > 0

    property real anchorX: 0
    property real anchorY: 0

    // Re-measured whenever the stack appears and whenever the bell changes
    // width, which it does every time the unread count gains a digit -- the
    // bar Row is right-anchored, so the bell's own width is what moves it.
    function reanchor(): void {
        const pos = root.anchorItem.mapToItem(null, 0, 0);
        root.anchorX = pos.x + root.anchorItem.width / 2;
        root.anchorY = pos.y + root.anchorItem.height;
    }

    screen: root.barScreen ?? FocusedScreen.screen

    // Mapped until the card has finished rolling up. Reading the card's height
    // rather than the animation's `running` is what keeps the surface from
    // blinking out mid-collapse.
    visible: root.present || card.height > 0

    color: "transparent"
    focusable: false

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    // An overlay layer surface otherwise swallows every pointer event in its
    // geometry for its whole lifetime.
    mask: Region {
        item: card
    }

    onVisibleChanged: {
        if (root.visible)
            root.reanchor();
    }

    Connections {
        target: root.anchorItem

        function onWidthChanged(): void {
            root.reanchor();
        }
    }

    Binding {
        target: NotificationService
        property: "popupsHovered"
        value: hover.hovered
    }

    Item {
        id: card

        x: Math.max(outline.flare, Math.min(root.anchorX - width / 2, parent.width - width - outline.flare))
        y: root.anchorY
        width: 400
        implicitHeight: stack.implicitHeight + root.padding * 2
        height: root.present ? implicitHeight : 0

        Behavior on height {
            NumberAnimation {
                duration: root.revealDuration
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: hover
        }

        AttachedOutline {
            id: outline

            visible: card.height > 0
            fillColor: Theme.barBackground
        }

        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: stack

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.padding
                spacing: 8

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
    }
}
