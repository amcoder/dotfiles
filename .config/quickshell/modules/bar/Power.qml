import QtQuick
import qs.config
import qs.modules.power
import qs.services
import qs.widgets

MouseArea {
    id: root

    implicitWidth: label.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: PowerService.toggle()

    Icon {
        id: label

        anchors.centerIn: parent
        name: "power"
        color: Theme.barStatusline
    }

    PowerMenu {
        anchorItem: root
    }
}
