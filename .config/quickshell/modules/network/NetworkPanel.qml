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
// The access point list gets a fixed height and scrolls inside it: a scan takes
// about five seconds to fill in, and a list that grows under a stationary
// cursor moves the row you were about to click.
//
// Asking for a password is PskDialog's job, not this file's -- a modal is the
// clearer place for it, and it is also where the field is certain to be
// typeable whatever the panel is built on.
BarPopup {
    id: root

    readonly property int rowHeight: 34
    readonly property int listRows: 5

    implicitWidth: 380

    // A Connections rather than an `onVisibleChanged`: a handler declared here
    // would replace ModalOverlay's own, which is what focuses the card and
    // re-measures its position.
    Connections {
        target: root

        function onVisibleChanged() {
            NetworkService.setScanning(root.visible);
        }
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
            root.visible = false;
            NetworkService.requestPsk(network);
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

    // Fixed height: the list fills in during a scan and must scroll inside
    // this rather than resize the popup. See the note at the top of the file.
    Item {
        width: parent.width
        height: heading.height + 4 + root.listRows * root.rowHeight
        visible: NetworkService.wifiEnabled

        Heading {
            id: heading

            anchors.left: parent.left
            anchors.top: parent.top
            text: "Networks"
            width: parent.width
            elide: Text.ElideRight
        }

        ListView {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: heading.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
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
    }
}
