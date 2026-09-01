import QtQuick
import qs.config

// A FocusScope so forceActiveFocus() on the field reaches the TextInput.
FocusScope {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode

    signal accepted

    implicitHeight: 40
    activeFocusOnTab: true

    onEnabledChanged: {
        if (root.enabled)
            root.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Theme.base
        border.color: input.activeFocus ? Theme.blue : Theme.surface1
        border.width: 1
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        focus: true
        color: Theme.popupText
        selectionColor: Theme.popupSelection
        selectedTextColor: Theme.popupText
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize

        onAccepted: root.accepted()
    }
}
