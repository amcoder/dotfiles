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

        // The bar's three sections, each full height so an item can measure
        // against `parent.height`; a new item goes into whichever one it
        // belongs in. The centre is anchored to the bar rather than laid out
        // between the other two, so an item growing on the left or the right
        // never shifts it.
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

        // The one section that is not a Row: the clock has to stay on the
        // bar's centre line, and a Row would slide it left by half of whatever
        // was added beside it. So the section spans the full width, the clock
        // is pinned to the middle of it, and anything else hangs off the
        // clock's own edge and grows outward. Only the children take input, so
        // spanning the bar does not shadow the sections either side.
        Item {
            id: centre

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Clock {
                id: clock

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            Recording {
                anchors.right: clock.left
                anchors.rightMargin: 12
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            Media {
                anchors.left: clock.right
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.bottom: parent.bottom
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

            Power {
                height: parent.height
            }
        }
    }
}
