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

        Workspaces {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 4
            anchors.topMargin: 3
            anchors.bottomMargin: 3

            screenName: bar.screen.name
        }

        Row {
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

            Clock {
                anchors.verticalCenter: parent.verticalCenter
            }

            Separator {}

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
