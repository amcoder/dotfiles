import QtQuick
import qs.services
import qs.widgets

MouseArea {
    id: root

    implicitWidth: label.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: InsomniaService.cycle()

    Icon {
        id: label

        anchors.centerIn: parent
        name: InsomniaService.mode.icon
        color: InsomniaService.mode.color
    }
}
