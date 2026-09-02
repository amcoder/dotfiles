import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The panel behind the bar's bluetooth icon, replacing blueman-applet's tray
// menu: adapter power, the paired devices with their battery level, and
// blueman-manager as the escape hatch for pairing a new one, which needs the
// BlueZ agent it owns.
BarPopup {
    id: root

    implicitWidth: 380

    component Heading: Text {
        color: Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize
    }

    component Link: Text {
        id: link

        signal activated

        color: linkMouse.containsMouse ? Theme.popupText : Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize

        MouseArea {
            id: linkMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: link.activated()
        }
    }

    // One device: class icon, name, connection status, and a forget button that
    // only appears under the cursor.
    component DeviceRow: ListRow {
        id: device

        required property var node

        height: 30
        selected: device.node.connected

        onActivated: BluetoothService.toggleConnected(device.node)

        Icon {
            id: kind

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            size: Appearance.smallFontSize + 4
            name: BluetoothService.deviceIcon(device.node)
            color: device.node.connected ? Theme.popupText : Theme.popupSubtext
        }

        Text {
            anchors.left: kind.right
            anchors.right: status.left
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothService.label(device.node)
            color: device.node.connected ? Theme.popupText : Theme.popupSubtext
            elide: Text.ElideRight
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Text {
            id: status

            anchors.right: forget.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: BluetoothService.status(device.node)
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        MouseArea {
            id: forget

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: visible ? Appearance.smallFontSize : 0
            implicitHeight: Appearance.smallFontSize
            visible: device.containsMouse && (device.node.paired || device.node.bonded)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: BluetoothService.forget(device.node)

            Icon {
                anchors.fill: parent
                size: Appearance.smallFontSize
                name: "x"
                color: forget.containsMouse ? Theme.red : Theme.popupSubtext
            }
        }
    }

    Item {
        width: parent.width
        implicitHeight: title.implicitHeight

        Text {
            id: title

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth"
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }

        Link {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "advanced…"

            onActivated: {
                root.expanded = false;
                BluetoothService.advanced();
            }
        }
    }

    // Power, in the position the audio panel gives its output level: the one
    // control the panel is most often opened for.
    ListRow {
        width: parent.width
        height: 30
        enabled: BluetoothService.available

        onActivated: BluetoothService.toggleEnabled()

        Icon {
            id: power

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            size: Appearance.iconSize
            name: BluetoothService.icon
            color: BluetoothService.enabled ? Theme.popupText : Theme.popupSubtext
        }

        Text {
            anchors.left: power.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (!BluetoothService.available)
                    return "No adapter";
                return BluetoothService.enabled ? "On" : "Off";
            }

            color: BluetoothService.enabled ? Theme.popupText : Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    Column {
        width: parent.width
        spacing: 4
        visible: BluetoothService.enabled

        Heading {
            text: "Devices"
        }

        Repeater {
            model: BluetoothService.devices

            DeviceRow {
                required property var modelData

                width: parent.width
                node: modelData
            }
        }
    }
}
