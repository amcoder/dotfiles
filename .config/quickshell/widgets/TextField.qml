import QtQuick
import qs.config

// A FocusScope so forceActiveFocus() on the field reaches the TextInput.
FocusScope {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder: ""

    // Items given first refusal on every key event, before the input reads it.
    // Home and End are only reachable this way: a TextInput accepts them for
    // cursor movement, so a handler further up the focus chain never sees them.
    property list<Item> keyHandlers

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

        Keys.forwardTo: root.keyHandlers

        onAccepted: root.accepted()

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }
}
