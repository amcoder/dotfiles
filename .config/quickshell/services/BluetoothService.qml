pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.I3

// Adapter power and per-device connect/forget for devices already paired,
// replacing blueman-applet's tray menu.
//
// Pairing is deliberately not here. Quickshell 0.3.0 talks to Adapter1,
// Device1 and Battery1 but registers no org.bluez.Agent1, so it cannot answer
// a PIN or confirmation prompt; and a scan list cannot refresh in a BarPopup,
// which takes its size when it maps. `advanced()` launches blueman-manager,
// which D-Bus-activates blueman-applet and with it the agent.
Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.adapter?.enabled ?? false

    // Sorted by label, and by label alone: a row must not move when its state
    // changes, or clicking a device slides the next one under the cursor --
    // and with it the forget button that appears there on hover.
    readonly property var devices: root.byLabel(device => device.paired || device.bonded)

    readonly property var connected: root.devices.filter(device => device.connected)

    readonly property string icon: {
        if (!root.available || !root.enabled)
            return "bluetooth-slash";
        if (root.connected.length > 0)
            return "bluetooth-connected";
        return "bluetooth";
    }

    // BlueZ reports a freedesktop icon name for the device class; map the ones
    // that reach this machine onto vendored Phosphor icons.
    readonly property var deviceIcons: ({
            "audio-card": "speaker-high",
            "audio-headphones": "headphones",
            "audio-headset": "headphones",
            "camera-photo": "video",
            "camera-video": "video",
            "computer": "laptop",
            "input-keyboard": "keyboard",
            "input-mouse": "mouse",
            "input-tablet": "keyboard",
            "multimedia-player": "music-note",
            "phone": "device-mobile"
        })

    function byLabel(predicate: var): var {
        const devices = Bluetooth.devices?.values ?? [];
        return devices.filter(predicate).sort((a, b) => root.label(a).localeCompare(root.label(b)));
    }

    function label(device: var): string {
        if (!device)
            return "";
        return device.name || device.deviceName || device.address;
    }

    function deviceIcon(device: var): string {
        return root.deviceIcons[device?.icon ?? ""] ?? "bluetooth";
    }

    function status(device: var): string {
        switch (device?.state ?? BluetoothDeviceState.Disconnected) {
        case BluetoothDeviceState.Connected:
            return device.batteryAvailable ? `${Math.round(device.battery * 100)}%` : "connected";
        case BluetoothDeviceState.Connecting:
            return "connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "disconnecting…";
        default:
            return device?.pairing ? "pairing…" : "";
        }
    }

    function setEnabled(enabled: bool): void {
        if (root.adapter)
            root.adapter.enabled = enabled;
    }

    function toggleEnabled(): void {
        root.setEnabled(!root.enabled);
    }

    function toggleConnected(device: var): void {
        if (!device)
            return;

        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    function forget(device: var): void {
        device?.forget();
    }

    function advanced(): void {
        I3.dispatch("exec blueman-manager");
    }
}
