pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, swap, load and network use, sampled once a second by
// `sysmon-watch`, with a minute of history for the panel's graphs. The
// per-process list is the one expensive read, so the watcher only scans it
// while `detail` is set, which the panel does for as long as it is open.
Singleton {
    id: root

    readonly property int historyLength: 60

    property real cpu: 0
    property var cores: []
    property var memory: ({
            total: 0,
            used: 0,
            cached: 0
        })
    property var swap: ({
            total: 0,
            used: 0
        })
    property var load: [0, 0, 0]
    property real uptime: 0
    property var net: ({
            rx: 0,
            tx: 0
        })
    property var processes: []

    property var cpuHistory: []
    property var memoryHistory: []
    property var netHistory: []

    // Whether the watcher scans processes. Set by the panel while open.
    property bool detail: false

    readonly property real memoryFraction: root.memory.total > 0 ? root.memory.used / root.memory.total : 0
    readonly property real swapFraction: root.swap.total > 0 ? root.swap.used / root.swap.total : 0

    onDetailChanged: root.sendDetail()

    function sendDetail(): void {
        if (watcher.running)
            watcher.write(root.detail ? "detail on\n" : "detail off\n");
    }

    function push(history: var, value: var): var {
        const next = history.concat([value]);
        return next.length > root.historyLength ? next.slice(next.length - root.historyLength) : next;
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

    function formatRate(bytesPerSecond: real): string {
        return `${root.formatBytes(bytesPerSecond)}/s`;
    }

    function formatUptime(seconds: real): string {
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        if (days > 0)
            return `${days}d ${hours % 24}h ${minutes % 60}m`;
        if (hours > 0)
            return `${hours}h ${minutes % 60}m`;
        return `${minutes}m`;
    }

    Process {
        id: watcher

        running: true
        command: ["sysmon-watch"]
        stdinEnabled: true

        onStarted: root.sendDetail()

        stdout: SplitParser {
            onRead: line => {
                let sample;
                try {
                    sample = JSON.parse(line);
                } catch (e) {
                    return;
                }

                root.cpu = sample.cpu;
                root.cores = sample.cores;
                root.memory = sample.mem;
                root.swap = sample.swap;
                root.load = sample.load;
                root.uptime = sample.uptime;
                root.net = sample.net;
                if (sample.procs !== undefined)
                    root.processes = sample.procs;

                root.cpuHistory = root.push(root.cpuHistory, sample.cpu);
                root.memoryHistory = root.push(root.memoryHistory, sample.mem.total > 0 ? sample.mem.used / sample.mem.total : 0);
                root.netHistory = root.push(root.netHistory, sample.net);
            }
        }
    }

    // A watcher that has died leaves the bar showing a stale reading, so it
    // is restarted the same way camera-watch is.
    Timer {
        interval: 10000
        running: !watcher.running
        onTriggered: watcher.running = true
    }
}
