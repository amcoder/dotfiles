import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland

PanelWindow {
    id: bar

    readonly property bool urgent: I3.workspaces.values.some(ws => ws.urgent && ws.monitor && ws.monitor.name === bar.screen.name)
    readonly property bool shown: BarVisibility.revealed || bar.urgent

    IdleInhibitor {
        window: bar
        enabled: InsomniaService.mode.inhibitIdle
    }

    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 31 + Theme.barBorderWidth
    exclusionMode: ExclusionMode.Ignore

    // The idle inhibitor only counts while its surface is mapped, so hiding
    // empties the bar rather than taking the window down.
    color: bar.shown ? Theme.barBackground : "transparent"
    mask: Region {
        item: bar.shown ? content : null
    }

    Item {
        id: content

        anchors.fill: parent
        visible: bar.shown

        Rectangle {
            id: topBorder

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.barBorderWidth

            color: Theme.barBorder
        }

        Workspaces {
            anchors.left: parent.left
            anchors.top: topBorder.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 4
            anchors.topMargin: 3
            anchors.bottomMargin: 3

            screenName: bar.screen.name
        }

        Row {
            anchors.right: parent.right
            anchors.top: topBorder.bottom
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

            Insomnia {
                height: parent.height
            }

            Separator {}

            Dunst {
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
