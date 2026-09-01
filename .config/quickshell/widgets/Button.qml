import QtQuick
import qs.config

Rectangle {
    id: root

    required property string text

    property color background: Theme.surface1
    property color hoverBackground: Theme.surface2
    property color foreground: Theme.popupText

    signal activated

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 38
    radius: 4
    activeFocusOnTab: true
    opacity: root.enabled ? 1 : 0.5
    color: mouse.containsMouse ? root.hoverBackground : root.background
    border.color: Theme.text
    border.width: root.activeFocus ? 2 : 0

    Keys.onSpacePressed: root.activated()
    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.activated()
    }
}
