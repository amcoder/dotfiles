import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

PanelWindow {
    id: bar

    IdleInhibitor {
        window: bar
        enabled: InsomniaService.mode.inhibitIdle
    }

    aboveWindows: true
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Appearance.barHeight
    exclusionMode: ExclusionMode.Auto

    color: Theme.barBackground

    Item {
        id: content

        anchors.fill: parent

        // The bar's three sections. Each is a full-height Row, so an item can
        // measure against `parent.height`; a new item goes into whichever one
        // it belongs in. The centre is anchored to the bar rather than laid
        // out between the other two, so an item growing on the left or the
        // right never shifts it.
        Row {
            id: left

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 4

            spacing: 12

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - 6

                screenName: bar.screen.name
            }
        }

        Row {
            id: centre

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            spacing: 12

            Clock {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Row {
            id: right

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: 8

            // Wider than the other sections: these items carried a separator
            // between each pair, and the gap has to stand in for it.
            spacing: 16

            AptUpgrade {
                height: parent.height
            }

            Volume {
                height: parent.height
            }

            Network {
                height: parent.height
            }

            Bluetooth {
                height: parent.height
            }

            Battery {
                height: parent.height
            }

            Mail {
                height: parent.height
            }

            ThemeToggle {
                height: parent.height
            }

            Insomnia {
                height: parent.height
            }

            NotificationIndicator {
                height: parent.height
            }

            Tray {
                height: parent.height
                window: bar
            }
        }
    }
}
