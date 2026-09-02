import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The history the bell drops down. One per bar rather than one for the
// session, because it hangs off the bell; the focused-screen gate is what
// keeps a single centre open when there is more than one bar.
BarPopup {
    id: root

    readonly property int maxHeight: 620

    namespaceSuffix: "notification-centre"

    cardWidth: 560
    focusItem: list

    onDismissed: NotificationService.hideCentre()

    onOpened: list.currentIndex = 0

    // Assigned rather than bound: BarPopup clears `expanded` when the card is
    // dismissed, and an assignment to a bound property breaks the binding for
    // good.
    Connections {
        target: NotificationService

        function onCentreVisibleChanged(): void {
            root.expanded = NotificationService.centreVisible && root.screen === FocusedScreen.screen;
        }
    }

    Item {
        width: parent.width
        height: heading.implicitHeight

        Row {
            id: heading

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: NotificationService.dnd ? "bell-slash" : "bell"
                color: NotificationService.dnd ? Theme.yellow : Theme.blue
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                id: dndLink

                anchors.verticalCenter: parent.verticalCenter
                text: NotificationService.dnd ? "resume" : "do not disturb"
                color: dndMouse.containsMouse ? Theme.popupText : Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize

                MouseArea {
                    id: dndMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: NotificationService.toggleDnd()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: NotificationService.history.length > 0
                text: "clear all"
                color: clearMouse.containsMouse ? Theme.red : Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize

                MouseArea {
                    id: clearMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: NotificationService.clearHistory()
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: NotificationService.history.length === 0
        text: "Nothing to show"
        color: Theme.popupSubtext
        horizontalAlignment: Text.AlignHCenter
        topPadding: 16
        bottomPadding: 16
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    ListView {
        id: list

        width: parent.width
        height: Math.min(list.contentHeight, root.maxHeight)
        visible: NotificationService.history.length > 0
        clip: true
        focus: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds

        model: NotificationService.history

        Keys.onReturnPressed: NotificationService.activate(NotificationService.history[list.currentIndex])
        Keys.onEnterPressed: NotificationService.activate(NotificationService.history[list.currentIndex])
        Keys.onDeletePressed: NotificationService.discard(NotificationService.history[list.currentIndex])

        delegate: NotificationCard {
            required property int index
            required property var modelData

            width: list.width
            entry: modelData
            showTime: true
            bodyLines: 3
            border.color: {
                if (list.currentIndex === index)
                    return Theme.blue;
                return critical ? Theme.red : Theme.popupBorder;
            }

            onDismissed: NotificationService.discard(modelData)
        }
    }
}
