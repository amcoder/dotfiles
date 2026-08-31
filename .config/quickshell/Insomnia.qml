import QtQuick

MouseArea {
    id: root

    implicitWidth: label.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: InsomniaService.cycle()

    Text {
        id: label

        anchors.centerIn: parent
        text: InsomniaService.mode.icon
        color: InsomniaService.mode.color
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSize
    }
}
