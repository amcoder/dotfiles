import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The panel behind the bar's network icon: the wifi radio, the wired link, the
// saved VPNs, and the access points in range. nm-connection-editor is the
// escape hatch for everything NetworkManager does that this does not --
// 802.1x, per-connection IP settings, and editing a VPN.
//
// The access point list is the one thing here that grows on its own: a scan
// takes about five seconds to fill in, and a PopupWindow is size-locked once
// it maps. So the list gets a fixed height and scrolls inside it, and the
// password prompt replaces it rather than being appended below it. Nothing in
// this panel may change the popup's implicit height while it is open.
BarPopup {
    id: root

    readonly property int rowHeight: 34
    readonly property int listRows: 5

    // The network awaiting a password, or null when the list is showing.
    property var pending: null

    implicitWidth: 380

    // Scanning belongs here rather than at the instantiation site: an
    // `onVisibleChanged` written next to `NetworkPanel { ... }` in the bar
    // would silently replace this handler instead of running alongside it.
    onVisibleChanged: {
        NetworkService.setScanning(root.visible);
        if (!root.visible)
            root.cancelPsk();
    }

    function promptPsk(network: var): void {
        root.pending = network;
        psk.text = "";
        psk.forceActiveFocus();
    }

    function cancelPsk(): void {
        root.pending = null;
        psk.text = "";
    }

    function submitPsk(): void {
        if (psk.text === "")
            return;
        NetworkService.connectWithPsk(root.pending, psk.text);
        root.cancelPsk();
    }

    // A known network connects on click; an unknown secured one needs a
    // password first, unless it is an EAP network, which needs the secret
    // agent this panel does not have.
    function activate(network: var): void {
        if (network.connected) {
            NetworkService.disconnect(network);
        } else if (network.known || !NetworkService.secured(network)) {
            NetworkService.connect(network);
        } else if (NetworkService.needsAgent(network)) {
            root.visible = false;
            NetworkService.advanced();
        } else {
            root.promptPsk(network);
        }
    }

    component Heading: Text {
        color: Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize
    }

    component Link: Text {
        id: link

        signal activated

        color: linkMouse.containsMouse ? Theme.popupText : Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize

        MouseArea {
            id: linkMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: link.activated()
        }
    }

    Item {
        width: parent.width
        implicitHeight: title.implicitHeight

        Text {
            id: title

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Network"
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }

        Link {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "advanced…"

            onActivated: {
                root.visible = false;
                NetworkService.advanced();
            }
        }
    }

    // Wifi power, in the position the audio and bluetooth panels give their
    // primary control.
    ListRow {
        width: parent.width
        height: root.rowHeight
        enabled: NetworkService.wifiAvailable && NetworkService.wifiHardwareEnabled

        onActivated: NetworkService.toggleWifiEnabled()

        Icon {
            id: wifiIcon

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            size: Appearance.iconSize
            name: NetworkService.wifiEnabled ? NetworkService.icon : "wifi-slash"
            color: NetworkService.wifiEnabled ? Theme.popupText : Theme.popupSubtext
        }

        Text {
            anchors.left: wifiIcon.right
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight

            text: {
                if (!NetworkService.wifiAvailable)
                    return "No adapter";
                if (!NetworkService.wifiHardwareEnabled)
                    return "Wifi blocked";
                if (!NetworkService.wifiEnabled)
                    return "Wifi off";
                return NetworkService.wifiNetwork?.name ?? "Not connected";
            }

            color: NetworkService.wifiEnabled ? Theme.popupText : Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    // Status only: a wired link is NetworkManager's to bring up, and there is
    // nothing here worth clicking.
    Item {
        width: parent.width
        height: root.rowHeight
        visible: NetworkService.wiredDevice !== null

        Icon {
            id: wiredIcon

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            size: Appearance.iconSize
            name: NetworkService.wiredConnected ? "plugs-connected" : "plugs"
            color: NetworkService.wiredConnected ? Theme.popupText : Theme.popupSubtext
        }

        Text {
            anchors.left: wiredIcon.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (NetworkService.wiredConnected)
                    return "Wired";
                return NetworkService.wiredHasLink ? "Cable connected" : "No cable";
            }

            color: NetworkService.wiredConnected ? Theme.popupText : Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    Column {
        width: parent.width
        spacing: 4
        visible: NetworkService.vpns.length > 0

        Heading {
            text: "VPN"
        }

        Repeater {
            model: NetworkService.vpns

            ListRow {
                id: vpn

                required property var modelData

                width: parent.width
                height: root.rowHeight
                selected: vpn.modelData.active

                onActivated: NetworkService.toggleVpn(vpn.modelData)

                Icon {
                    id: vpnIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    size: Appearance.smallFontSize + 4
                    name: "shield-check"
                    color: vpn.modelData.active ? Theme.green : Theme.popupSubtext
                }

                Text {
                    anchors.left: vpnIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: vpn.modelData.name
                    color: vpn.modelData.active ? Theme.popupText : Theme.popupSubtext
                    elide: Text.ElideRight
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }
            }
        }
    }

    // Fixed height, holding either the access points or the password prompt.
    // Neither may resize it: see the note at the top of the file.
    Item {
        width: parent.width
        height: heading.height + 4 + root.listRows * root.rowHeight
        visible: NetworkService.wifiEnabled

        Heading {
            id: heading

            anchors.left: parent.left
            anchors.top: parent.top
            text: root.pending ? `Password for ${root.pending.name}` : "Networks"
            width: parent.width
            elide: Text.ElideRight
        }

        ListView {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            visible: !root.pending
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: NetworkService.networks

            delegate: ListRow {
                id: network

                required property var modelData

                width: ListView.view.width
                height: root.rowHeight
                selected: network.modelData.connected

                onActivated: root.activate(network.modelData)

                Icon {
                    id: strength

                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    size: Appearance.smallFontSize + 4
                    name: NetworkService.strengthIcon(network.modelData.signalStrength)
                    color: network.modelData.connected ? Theme.popupText : Theme.popupSubtext
                }

                Text {
                    anchors.left: strength.right
                    anchors.right: state.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: network.modelData.name
                    color: network.modelData.connected ? Theme.popupText : Theme.popupSubtext
                    elide: Text.ElideRight
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }

                Text {
                    id: state

                    anchors.right: secured.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkService.status(network.modelData)
                    color: Theme.popupSubtext
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }

                Icon {
                    id: secured

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NetworkService.secured(network.modelData)
                    size: Appearance.smallFontSize
                    name: "lock-key"
                    color: network.modelData.known ? Theme.popupText : Theme.popupSubtext
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.bottom
            anchors.topMargin: 4
            visible: root.pending !== null
            spacing: 8

            TextField {
                id: psk

                width: parent.width
                enabled: root.pending !== null
                echoMode: TextInput.Password
                placeholder: "Password"

                onAccepted: root.submitPsk()
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                Button {
                    text: "Cancel"

                    onActivated: root.cancelPsk()
                }

                Button {
                    text: "Connect"
                    enabled: psk.text !== ""
                    background: Theme.blue
                    hoverBackground: Theme.sapphire
                    foreground: Theme.crust

                    onActivated: root.submitPsk()
                }
            }
        }
    }
}
