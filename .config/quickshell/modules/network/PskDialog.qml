import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The password prompt for an unknown WPA network.
//
// It is a ModalOverlay rather than a row inside NetworkPanel because a
// PopupWindow cannot hold keyboard focus: keys go to the parent layer surface,
// which is a different window, so a field inside the panel shows a caret and
// then never receives a character. A layer surface with exclusive focus can.
ModalOverlay {
    id: root

    readonly property var network: NetworkService.pskNetwork

    function submit(): void {
        if (input.text === "")
            return;

        NetworkService.submitPsk(input.text);
        input.text = "";
    }

    namespaceSuffix: "network-psk"

    visible: root.network !== null
    cardWidth: 460
    padding: 20
    closeOnClickOutside: true
    focusItem: input

    onDismissed: {
        input.text = "";
        NetworkService.cancelPsk();
    }

    Row {
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "lock-key"
            color: Theme.yellow
            size: Appearance.headingFontSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Wifi password"
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.headingFontSize
            font.bold: true
        }
    }

    Text {
        width: parent.width
        text: root.network?.name ?? ""
        color: Theme.popupSubtext
        elide: Text.ElideRight
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    TextField {
        id: input

        width: parent.width
        echoMode: TextInput.Password
        placeholder: "Password"

        onAccepted: root.submit()
    }

    Row {
        anchors.right: parent.right
        spacing: 8

        Button {
            text: "Cancel"

            onActivated: root.dismissed()
        }

        Button {
            text: "Connect"
            enabled: input.text !== ""
            background: Theme.blue
            hoverBackground: Theme.sapphire
            foreground: Theme.crust

            onActivated: root.submit()
        }
    }
}
