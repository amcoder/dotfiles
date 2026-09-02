import QtQuick
import qs.config
import qs.modules.bluetooth
import qs.services
import qs.widgets

MouseArea {
    id: root

    visible: BluetoothService.available
    implicitWidth: visible ? icon.implicitWidth : 0
    cursorShape: Qt.PointingHandCursor

    onClicked: panel.toggle()

    Icon {
        id: icon

        anchors.centerIn: parent
        name: BluetoothService.icon
        color: BluetoothService.enabled ? Theme.barStatusline : Theme.overlay1
    }

    BluetoothPanel {
        id: panel

        anchorItem: root
    }
}
