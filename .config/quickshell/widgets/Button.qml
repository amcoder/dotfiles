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

    // A held key repeats at the compositor's rate, and a button that fires 25
    // times a second is wrong everywhere -- but it matters most where a dialog
    // opens under a key that is still down, which is how CountdownDialog is
    // reached from the power menu.
    Keys.onPressed: event => {
        if (event.isAutoRepeat)
            return;
        if (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
            return;

        root.activated();
        event.accepted = true;
    }

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
