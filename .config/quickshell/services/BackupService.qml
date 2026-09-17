pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// What the backup units are doing, read from the status file `backup-record`
// keeps for them: whether one is running, how the last run ended, and when
// the last one succeeded. Every state change is a write to that file, so the
// FileView's watch is the whole of the change signal; nothing here polls
// systemd. The one exception is a sanity check of "running" against
// `systemctl is-active`, because a record that was never finished -- a power
// cut mid-backup -- would otherwise say running for ever.
Singleton {
    id: root

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/backup`

    property var status: ({})

    readonly property bool running: root.status.state === "running"
    readonly property var current: root.status.current ?? null
    readonly property var last: root.status.last ?? null
    readonly property var lastSuccess: root.status.lastSuccess ?? null

    // A skip (the NAS away) and a stop (asked for) are not failures.
    readonly property bool failed: root.last !== null && !["success", "exec-condition", "stopped"].includes(root.last.result)

    // Seconds since the last success, or -1 with none on record.
    property int sinceSuccess: -1
    // Hours without a successful backup before the icon says so.
    readonly property int staleAfter: 48 * 3600
    readonly property bool stale: root.sinceSuccess < 0 || root.sinceSuccess > root.staleAfter

    property int elapsed: 0

    // The next timer to fire, as an epoch second, or 0 when unknown.
    property real next: 0

    property bool panelOpen: false

    function refreshClock(): void {
        const now = Math.floor(Date.now() / 1000);
        root.elapsed = root.running && root.current ? Math.max(0, now - root.current.started) : 0;
        root.sinceSuccess = root.lastSuccess ? Math.max(0, now - root.lastSuccess.finished) : -1;
    }

    function start(): void {
        control.command = ["systemctl", "--user", "start", "--no-block", "backup-daily.service"];
        control.running = true;
    }

    function stop(): void {
        const interval = root.current?.interval ?? "daily";
        control.command = ["systemctl", "--user", "stop", "--no-block", `backup-${interval}.service`];
        control.running = true;
    }

    // Through sway's exec, so the window lands in sway's scope.
    function browse(): void {
        I3.dispatch("exec backup-browser");
    }

    function refreshNext(): void {
        nextTimer.running = true;
    }

    function verifyRunning(): void {
        if (root.running)
            verify.running = true;
    }

    function formatBytes(bytes: real): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return `${value.toFixed(value >= 100 || unit === 0 ? 0 : 1)} ${units[unit]}`;
    }

    function formatDuration(seconds: int): string {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        if (h > 0)
            return `${h}h ${m}m`;
        if (m > 0)
            return `${m}m ${s}s`;
        return `${s}s`;
    }

    // "today 00:11", "yesterday 00:02", "Mon 14 Sep 00:31", "4 Sep 2026".
    function formatWhen(epoch: real): string {
        const date = new Date(epoch * 1000);
        const now = new Date();
        const day = d => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        const days = Math.round((day(now) - day(date)) / 86400000);
        const time = Qt.formatTime(date, "HH:mm");
        if (days === 0)
            return `today ${time}`;
        if (days === 1)
            return `yesterday ${time}`;
        if (days === -1)
            return `tomorrow ${time}`;
        if (days > 1 && days < 7)
            return `${Qt.formatDate(date, "ddd d MMM")} ${time}`;
        if (date.getFullYear() === now.getFullYear())
            return `${Qt.formatDate(date, "d MMM")} ${time}`;
        return Qt.formatDate(date, "d MMM yyyy");
    }

    onStatusChanged: {
        root.refreshClock();
        root.refreshNext();
        root.verifyRunning();
    }

    IpcHandler {
        target: "backup"

        function toggle(): void {
            root.panelOpen = !root.panelOpen;
        }

        function start(): void {
            root.start();
        }

        function browse(): void {
            root.browse();
        }
    }

    FileView {
        id: file

        path: `${root.stateDir}/status.json`
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()

        onLoaded: {
            try {
                root.status = JSON.parse(file.text());
            } catch (e) {
                root.status = {};
            }
        }

        // No file yet is the state before the first recorded run; a watch on
        // a missing path never fires, so the load is retried until it exists.
        onLoadFailed: {
            root.status = {};
            retry.running = true;
        }
    }

    Timer {
        id: retry

        interval: 30000

        onTriggered: file.reload()
    }

    Process {
        id: control
    }

    // `--timestamp=unix` prints the epoch as `@N`, which needs no parsing of a
    // localised date. Three timers, and the soonest wins.
    Process {
        id: nextTimer

        command: ["systemctl", "--user", "show", "--timestamp=unix", "-p", "NextElapseUSecRealtime", "--value", "backup-daily.timer", "backup-weekly.timer", "backup-yearly.timer"]

        stdout: StdioCollector {
            onStreamFinished: {
                const times = text.split("\n").map(line => Number(line.trim().replace(/^@/, ""))).filter(n => n > 0);
                root.next = times.length > 0 ? Math.min(...times) : 0;
            }
        }
    }

    Process {
        id: verify

        command: ["systemctl", "--user", "is-active", "backup-daily.service", "backup-weekly.service", "backup-yearly.service"]

        stdout: StdioCollector {
            onStreamFinished: {
                const states = text.trim().split("\n");
                if (root.running && !states.some(s => s === "active" || s === "activating" || s === "deactivating"))
                    root.status = Object.assign({}, root.status, {
                        state: "idle"
                    });
            }
        }
    }

    Timer {
        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            root.refreshClock();
            // The file says running; make sure systemd agrees, now and then.
            if (root.running && root.elapsed % 30 === 0)
                root.verifyRunning();
        }
    }
}
