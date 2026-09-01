import QtQuick
import qs.config
import qs.services
import qs.widgets

MouseArea {
    id: root

    implicitWidth: label.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: ThemeService.toggle()

    Icon {
        id: label

        anchors.centerIn: parent
        name: "palette"
        color: Theme.barStatusline
    }
}
