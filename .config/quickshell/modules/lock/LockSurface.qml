import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// What one output shows while the session is locked: the current theme's
// wallpaper, a clock, and a password field.
//
// It is instantiated once per screen -- by WlSessionLock for a real lock, and
// by a plain overlay window under QS_LOCK_DEMO -- so it owns no window chrome
// of its own and fills whatever it is given.
Item {
    id: root

    focus: true

    // The same centred, unscaled, clipped composition Wallpaper.qml draws, over
    // the same crust -- the wallpapers carry no background of their own.
    Rectangle {
        anchors.fill: parent
        color: Theme.crust
        clip: true

        Image {
            anchors.centerIn: parent
            source: Theme.wallpaper ? `${Paths.wallpapers}/${Theme.wallpaper}` : ""
            asynchronous: true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayScrim
    }

    Column {
        anchors.centerIn: parent
        spacing: 32

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.text
                font.family: Appearance.fontFamily
                font.pixelSize: 120
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: Theme.subtext0
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            implicitHeight: card.implicitHeight + 48
            color: Theme.popupBackground
            border.color: Theme.popupBorder
            border.width: 1
            radius: 8

            Column {
                id: card

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 16

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "lock-key"
                        size: Appearance.iconSize
                        color: Theme.subtext1
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Quickshell.env("USER")
                        color: Theme.popupText
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                    }
                }

                TextField {
                    id: field

                    width: parent.width
                    enabled: !LockService.busy
                    echoMode: TextInput.Password
                    placeholder: LockService.busy ? "Checking\u2026" : "Password"

                    onAccepted: {
                        LockService.tryUnlock(field.text);
                        field.text = "";
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: LockService.status !== ""
                    text: LockService.status
                    color: LockService.statusIsError ? Theme.red : Theme.popupSubtext
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }
            }
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // A failed attempt leaves the field empty and focused, ready for the retry.
    Connections {
        target: LockService

        function onFailed(): void {
            field.forceActiveFocus();
        }
    }

    Component.onCompleted: field.forceActiveFocus()
}
