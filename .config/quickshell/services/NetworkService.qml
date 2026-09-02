pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Networking

// Wifi radio, the visible access points and the saved VPNs, replacing the part
// of nm-applet's menu that gets used. nm-applet itself keeps running as
// NetworkManager's secret agent -- Quickshell registers none, and an
// openconnect VPN whose cookie is flagged not-saved cannot connect without one
// -- so `Tray` filters its icon out rather than the session dropping it.
//
// Quickshell.Networking has no VPN concept, so that half is nmcli: `nmcli
// monitor` as the change signal and a one-shot `connection show` to re-read.
Singleton {
    id: root

    // Reading `devices` is what starts the scan; until then every value reads
    // empty, exactly as DesktopEntries does. `Network.qml` in the bar is what
    // warms it at startup.
    readonly property var devices: Networking.devices?.values ?? []

    readonly property var wifiDevice: root.devices.find(device => device.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: root.devices.find(device => device.type === DeviceType.Wired) ?? null

    readonly property bool wifiAvailable: root.wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    readonly property var wifiNetwork: (root.wifiDevice?.networks?.values ?? []).find(network => network.connected) ?? null
    readonly property bool wifiConnected: root.wifiNetwork !== null

    readonly property bool wiredConnected: root.wiredDevice?.connected ?? false
    readonly property bool wiredHasLink: root.wiredDevice?.hasLink ?? false

    readonly property int connectivity: Networking.connectivity
    readonly property bool online: root.connectivity === NetworkConnectivity.Full
    readonly property bool portal: root.connectivity === NetworkConnectivity.Portal

    // Sorted by name, and by name alone. Signal strength moves constantly, so
    // sorting by it -- or by connected-ness, which a click changes -- slides
    // the next row under the cursor mid-click.
    readonly property var networks: {
        const all = root.wifiDevice?.networks?.values ?? [];
        return all.filter(network => network.name !== "").sort((a, b) => a.name.localeCompare(b.name));
    }

    property var vpns: []

    // The network waiting on a password. A PopupWindow cannot hold keyboard
    // focus, so the prompt cannot live in the panel -- PskDialog watches this
    // and asks on a ModalOverlay, which can.
    property var pskNetwork: null

    readonly property var activeVpns: root.vpns.filter(vpn => vpn.active)

    readonly property string icon: {
        if (root.wiredConnected)
            return "plugs-connected";
        if (!root.wifiAvailable || !root.wifiEnabled)
            return "wifi-slash";
        if (!root.wifiConnected)
            return "wifi-none";
        return root.strengthIcon(root.wifiNetwork.signalStrength);
    }

    readonly property string label: {
        if (root.wiredConnected)
            return "Wired";
        if (!root.wifiEnabled)
            return "Off";
        return root.wifiNetwork?.name ?? "Not connected";
    }

    // The scanner is off by default and the list fills in over ~5s once it is
    // on, so the panel turns it on while it is open and off again after.
    function setScanning(scanning: bool): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = scanning;
    }

    function strengthIcon(strength: real): string {
        if (strength >= 0.7)
            return "wifi-high";
        if (strength >= 0.4)
            return "wifi-medium";
        if (strength >= 0.15)
            return "wifi-low";
        return "wifi-none";
    }

    function secured(network: var): bool {
        return (network?.security ?? WifiSecurityType.Open) !== WifiSecurityType.Open;
    }

    // Everything WifiSecurityType calls EAP needs a secret agent to answer the
    // 802.1x challenge, which is nm-applet's job and not this panel's.
    function needsAgent(network: var): bool {
        switch (network?.security ?? WifiSecurityType.Open) {
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.DynamicWep:
        case WifiSecurityType.Leap:
        case WifiSecurityType.Wpa3SuiteB192:
            return true;
        default:
            return false;
        }
    }

    function status(network: var): string {
        switch (network?.state ?? ConnectionState.Disconnected) {
        case ConnectionState.Connected:
            return "connected";
        case ConnectionState.Connecting:
            return "connecting…";
        case ConnectionState.Disconnecting:
            return "disconnecting…";
        default:
            return "";
        }
    }

    function setWifiEnabled(enabled: bool): void {
        Networking.wifiEnabled = enabled;
    }

    function toggleWifiEnabled(): void {
        root.setWifiEnabled(!root.wifiEnabled);
    }

    function connect(network: var): void {
        network?.connect();
    }

    function requestPsk(network: var): void {
        root.pskNetwork = network;
    }

    function cancelPsk(): void {
        root.pskNetwork = null;
    }

    function submitPsk(psk: string): void {
        root.pskNetwork?.connectWithPsk(psk);
        root.pskNetwork = null;
    }

    function disconnect(network: var): void {
        network?.disconnect();
    }

    function forget(network: var): void {
        network?.forget();
    }

    function toggleVpn(vpn: var): void {
        if (!vpn)
            return;
        vpnToggle.exec(["nmcli", "connection", vpn.active ? "down" : "up", "uuid", vpn.uuid]);
    }

    function advanced(): void {
        I3.dispatch("exec nm-connection-editor");
    }

    Component.onCompleted: vpnList.running = true

    // `nmcli -t` escapes a literal colon in a field as "\:", and only the name
    // can contain one, so split the fixed trailing fields off the right.
    Process {
        id: vpnList

        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,STATE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.trim().split("\n")) {
                    if (line === "")
                        continue;
                    const parts = line.split(":");
                    if (parts.length < 4)
                        continue;
                    const state = parts.pop();
                    const type = parts.pop();
                    const uuid = parts.pop();
                    if (type !== "vpn" && type !== "wireguard")
                        continue;
                    found.push({
                        name: parts.join(":").replace("\\:", ":"),
                        uuid: uuid,
                        type: type,
                        active: state === "activated"
                    });
                }
                root.vpns = found.sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }

    Process {
        id: vpnToggle

        onExited: vpnList.running = true
    }

    // nmcli monitor prints a line on every connection change; the debounce
    // collapses the burst a single up/down produces.
    Process {
        running: true
        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: vpnDebounce.restart()
        }
    }

    Timer {
        id: vpnDebounce

        interval: 200

        onTriggered: vpnList.running = true
    }
}
