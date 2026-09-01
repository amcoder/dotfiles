import QtQuick
import Quickshell
import qs.config
import qs.widgets

// A modal where waiting is what confirms: it counts down and fires `accepted`
// at zero, so an action announces itself and offers an escape rather than
// asking a question nobody answers. The accept button holds focus, so picking
// an action and pressing Return goes straight through; Escape and Cancel are
// the way out, along with simply doing nothing until the countdown ends.
//
// A dialog that waits for an answer instead of going ahead is a different
// thing; `ConfirmDialog` is free for it.
ModalOverlay {
    id: root

    required property string title

    // Seconds before `accepted` fires on its own.
    required property int countdown

    property string acceptText: "Yes"
    property string rejectText: "Cancel"

    property int remaining: 0

    signal accepted
    signal rejected

    namespaceSuffix: "countdown"
    closeOnClickOutside: true
    cardWidth: 460
    focusItem: accept

    onDismissed: root.rejected()

    onOpened: {
        root.remaining = root.countdown;
        tick.restart();
    }

    onVisibleChanged: {
        if (!root.visible)
            tick.stop();
    }

    Timer {
        id: tick

        interval: 1000
        repeat: true

        onTriggered: {
            root.remaining--;

            if (root.remaining > 0)
                return;

            tick.stop();
            root.accepted();
        }
    }

    Text {
        width: parent.width
        text: root.title
        color: Theme.popupText
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.headingFontSize
    }

    Text {
        width: parent.width
        text: root.remaining === 1 ? `${root.acceptText} in 1 second` : `${root.acceptText} in ${root.remaining} seconds`
        color: Theme.red
        wrapMode: Text.WordWrap
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    Item {
        width: parent.width
        implicitHeight: buttons.implicitHeight

        Row {
            id: buttons

            anchors.right: parent.right
            spacing: 10

            Button {
                id: reject

                text: root.rejectText
                KeyNavigation.right: accept

                onActivated: root.rejected()
            }

            Button {
                id: accept

                text: root.acceptText
                background: Theme.red
                hoverBackground: Theme.maroon
                foreground: Theme.base
                KeyNavigation.left: reject

                onActivated: root.accepted()
            }
        }
    }
}
