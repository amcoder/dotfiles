import QtQuick
import Quickshell.Services.UPower

Row {
    id: root

    readonly property int laptopVisibleCharge: 80
    readonly property int peripheralVisibleCharge: 50

    readonly property var devices: UPower.devices.values.filter(device => root.shouldShow(device))

    property bool expanded: false

    visible: root.devices.length > 0
    spacing: 12

    function shouldShow(device: UPowerDevice): bool {
        if (!device.isPresent || device.type === UPowerDeviceType.LinePower)
            return false;

        const threshold = device.isLaptopBattery ? root.laptopVisibleCharge : root.peripheralVisibleCharge;
        return root.percentOf(device) <= threshold;
    }

    function percentOf(device: UPowerDevice): int {
        return Math.round(device.percentage * 100);
    }

    function deviceIcon(device: UPowerDevice): string {
        if (device.isLaptopBattery)
            return "laptop";

        switch (device.type) {
        case UPowerDeviceType.Mouse:
            return "mouse";
        case UPowerDeviceType.Keyboard:
            return "keyboard";
        case UPowerDeviceType.Headset:
        case UPowerDeviceType.Headphones:
            return "headphones";
        case UPowerDeviceType.Phone:
            return "device-mobile";
        default:
            return "question";
        }
    }

    function chargeIcon(percent: int): string {
        if (percent >= 90)
            return "battery-full";
        if (percent >= 65)
            return "battery-high";
        if (percent >= 40)
            return "battery-medium";
        if (percent >= 15)
            return "battery-low";
        return "battery-empty";
    }

    function chargeColor(percent: int): color {
        if (percent >= 40)
            return Theme.barStatusline;
        if (percent >= 15)
            return Theme.yellow;
        return Theme.red;
    }

    function detailText(device: UPowerDevice): string {
        const percent = `${root.percentOf(device)}%`;

        if (device.state === UPowerDeviceState.Discharging && device.timeToEmpty > 0)
            return `${percent} (${root.formatDuration(device.timeToEmpty)} remaining)`;
        if (device.state === UPowerDeviceState.Charging && device.timeToFull > 0)
            return `${percent} (${root.formatDuration(device.timeToFull)} to full)`;
        return percent;
    }

    function formatDuration(seconds: real): string {
        const minutes = Math.round(seconds / 60);
        return `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}`;
    }

    Repeater {
        model: root.devices

        MouseArea {
            id: entry

            required property UPowerDevice modelData

            readonly property int percent: root.percentOf(entry.modelData)
            readonly property bool charging: entry.modelData.isLaptopBattery && entry.modelData.state !== UPowerDeviceState.Discharging

            implicitWidth: layout.implicitWidth
            height: root.height
            cursorShape: Qt.PointingHandCursor

            onClicked: root.expanded = !root.expanded

            Row {
                id: layout

                anchors.centerIn: parent
                spacing: 6

                Icon {
                    name: root.deviceIcon(entry.modelData)
                    color: Theme.barStatusline
                }

                Icon {
                    visible: entry.charging
                    name: "lightning"
                    color: Theme.barStatusline
                }

                Icon {
                    name: root.chargeIcon(entry.percent)
                    color: root.chargeColor(entry.percent)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.expanded
                    text: root.detailText(entry.modelData)
                    color: Theme.barStatusline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                }
            }
        }
    }
}
