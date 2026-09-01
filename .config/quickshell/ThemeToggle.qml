import QtQuick

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
