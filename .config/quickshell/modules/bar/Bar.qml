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
        // measure against `parent.height` and a Separator can size itself off
        // it; a new item goes into whichever one it belongs in. The centre is
        // anchored to the bar rather than laid out between the other two, so
        // an item growing on the left or the right never shifts it.
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

            spacing: 12

            AptUpgrade {
                id: aptUpgrade

                height: parent.height
            }

            Separator {
                visible: aptUpgrade.visible
            }

            Volume {
                id: volume

                height: parent.height
            }

            Separator {}

            Network {
                id: network

                height: parent.height
            }

            Separator {}

            Bluetooth {
                id: bluetooth

                height: parent.height
            }

            Separator {
                visible: bluetooth.visible
            }

            Battery {
                id: battery

                height: parent.height
            }

            Separator {
                visible: battery.visible
            }

            Mail {
                id: mail

                height: parent.height
            }

            Separator {
                visible: mail.visible
            }

            ThemeToggle {
                height: parent.height
            }

            Separator {}

            Insomnia {
                height: parent.height
            }

            Separator {}

            NotificationIndicator {
                height: parent.height
            }

            Separator {}

            Tray {
                height: parent.height
                window: bar
            }
        }
    }
}
