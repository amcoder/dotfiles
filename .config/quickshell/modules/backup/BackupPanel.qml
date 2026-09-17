import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The panel behind the bar's backup icon: what the backup units are doing now,
// how the last run went, when the last one succeeded and what it moved, and
// when the next is due -- with a button to run one now, or stop the one
// running, and one to open the browser over the snapshots on the NAS.
BarPopup {
    id: root

    cardWidth: 400

    onExpandedChanged: {
        if (root.expanded)
            BackupService.refreshNext();
        else
            BackupService.panelOpen = false;
    }

    // Assigned rather than bound: BarPopup clears `expanded` on dismiss, and
    // an assignment to a bound property breaks the binding for good.
    Connections {
        target: BackupService

        function onPanelOpenChanged(): void {
            root.expanded = BackupService.panelOpen && root.screen === FocusedScreen.screen;
        }
    }

    readonly property var last: BackupService.last
    readonly property var success: BackupService.lastSuccess
    readonly property var stats: root.success?.stats ?? null

    readonly property string statusText: {
        if (BackupService.running)
            return `Backing up (${BackupService.current?.interval ?? "daily"}) · ${BackupService.formatDuration(BackupService.elapsed)}`;
        if (root.last === null)
            return "No backup recorded yet";
        if (root.last.result === "success")
            return `Backed up ${BackupService.formatWhen(root.last.finished)}`;
        if (root.last.result === "exec-condition")
            return `Skipped ${BackupService.formatWhen(root.last.finished)}`;
        if (root.last.result === "stopped")
            return `Stopped ${BackupService.formatWhen(root.last.finished)}`;
        return `Failed ${BackupService.formatWhen(root.last.finished)}`;
    }

    readonly property color statusColor: {
        if (BackupService.running)
            return Theme.blue;
        if (BackupService.failed)
            return Theme.red;
        if (BackupService.stale)
            return Theme.yellow;
        return Theme.popupText;
    }

    component Detail: Item {
        id: detail

        required property string label
        property string value: ""
        property color valueColor: Theme.popupText

        width: parent.width
        implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)
        visible: detail.value !== ""

        Text {
            id: labelText

            anchors.left: parent.left
            anchors.top: parent.top
            width: 110
            text: detail.label
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Text {
            id: valueText

            anchors.left: labelText.right
            anchors.right: parent.right
            anchors.top: parent.top
            text: detail.value
            color: detail.valueColor
            wrapMode: Text.Wrap
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    Row {
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "clock-counter-clockwise"
            color: root.statusColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Backups"
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    Text {
        width: parent.width
        text: root.statusText
        color: root.statusColor
        wrapMode: Text.Wrap
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    Text {
        width: parent.width
        visible: !BackupService.running && root.last !== null && root.last.result !== "success" && root.last.message !== ""
        text: root.last?.message ?? ""
        color: Theme.popupSubtext
        wrapMode: Text.Wrap
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize
    }

    Column {
        width: parent.width
        spacing: 6

        Detail {
            label: "Last success"
            value: root.success ? `${BackupService.formatWhen(root.success.finished)} (${root.success.interval})` : "none recorded"
            valueColor: BackupService.stale ? Theme.yellow : Theme.popupText
        }

        Detail {
            label: "Took"
            value: root.success ? BackupService.formatDuration(root.success.finished - root.success.started) : ""
        }

        Detail {
            label: "Transferred"
            value: root.stats && root.stats.transferred !== undefined ? `${root.stats.transferred.toLocaleString()} files, ${BackupService.formatBytes(root.stats.transferredSize ?? 0)} (${BackupService.formatBytes(root.stats.sent ?? 0)} sent)` : ""
        }

        Detail {
            label: "Backed up"
            value: root.stats && root.stats.files !== undefined ? `${root.stats.files.toLocaleString()} files, ${BackupService.formatBytes(root.stats.totalSize ?? 0)}` : ""
        }

        Detail {
            label: "Next"
            value: BackupService.next > 0 ? BackupService.formatWhen(BackupService.next) : ""
        }
    }

    Row {
        spacing: 8

        Button {
            text: BackupService.running ? "Stop" : "Back up now"
            background: BackupService.running ? Theme.surface1 : Theme.blue
            hoverBackground: BackupService.running ? Theme.surface2 : Theme.sapphire
            foreground: BackupService.running ? Theme.popupText : Theme.base

            onActivated: {
                if (BackupService.running)
                    BackupService.stop();
                else
                    BackupService.start();
            }
        }

        Button {
            text: "Browse…"

            onActivated: {
                root.expanded = false;
                BackupService.browse();
            }
        }
    }
}
