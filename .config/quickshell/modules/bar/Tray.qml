import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config

Row {
    id: root

    required property var window

    // nm-applet stays running as NetworkManager's secret agent -- Quickshell
    // registers none, and the openconnect VPN's cookie is flagged not-saved --
    // but the bar has its own network item, so its tray icon is dropped rather
    // than shown twice.
    readonly property var hidden: ["nm-applet"]

    spacing: 8

    Repeater {
        model: SystemTray.items.values.filter(item => !root.hidden.includes(item.id))

        MouseArea {
            id: item

            required property SystemTrayItem modelData

            implicitWidth: Appearance.trayIconSize
            height: root.height
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: event => {
                if (event.button === Qt.MiddleButton) {
                    item.modelData.secondaryActivate();
                } else if (event.button === Qt.RightButton || item.modelData.onlyMenu) {
                    const pos = item.mapToItem(null, 0, 0);
                    item.modelData.display(root.window, pos.x, pos.y);
                } else {
                    item.modelData.activate();
                }
            }

            onWheel: event => {
                if (event.angleDelta.y !== 0)
                    item.modelData.scroll(event.angleDelta.y, false);
                if (event.angleDelta.x !== 0)
                    item.modelData.scroll(event.angleDelta.x, true);
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: Appearance.trayIconSize
                source: item.modelData.icon
            }
        }
    }
}
