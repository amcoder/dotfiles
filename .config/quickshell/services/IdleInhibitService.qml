pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What is holding the session awake, from both mechanisms that can hold it:
// a Wayland idle inhibitor on a window, and a logind idle inhibitor on a
// process.
//
// Only the Wayland half reaches IdleService, whose IdleMonitors follow the
// compositor's idle notification and nothing else. A logind inhibitor holds
// off logind's own idle action instead -- and Insomnia's own third mode, which
// IdleService reads directly. Both are reported here, because both are answers
// to "why is the screen still on".
//
// Neither side has a change signal to subscribe to. Sway emits no IPC event
// when a client takes or drops an inhibitor, and logind's BlockInhibited says
// only whether *something* holds idle, not what -- so this polls, at ~7ms a
// pair of reads.
Singleton {
    id: root

    readonly property int refreshInterval: 5000

    property var windowInhibitors: []
    property var systemInhibitors: []

    readonly property bool inhibited: root.windowInhibitors.length > 0 || root.systemInhibitors.length > 0

    function refresh(): void {
        tree.running = true;
        locks.running = true;
    }

    // Sway's own test for whether an inhibitor is holding idle off, which is
    // not the same as one existing: an application inhibitor counts only while
    // its window is visible, and each `inhibit_idle` mode has a test of its
    // own. Returns the row to list, or "" for a window holding nothing.
    function inhibitorLabel(node: var, fullscreen: bool): string {
        const state = node.idle_inhibitors;
        if (!state)
            return "";

        const title = node.name || node.app_id || node.window_properties?.class || "window";

        if (root.userHolds(node, state.user, fullscreen))
            return `${title} (inhibit_idle ${state.user})`;

        if (state.application === "enabled" && node.visible === true)
            return title;

        return "";
    }

    function userHolds(node: var, mode: string, fullscreen: bool): bool {
        if (mode === "open")
            return true;
        if (mode === "visible")
            return node.visible === true;
        if (mode === "focus")
            return root.focusedWithin(node);
        if (mode === "fullscreen")
            return fullscreen && node.visible === true;

        return false;
    }

    function focusedWithin(node: var): bool {
        return node.focused === true || root.childNodes(node).some(child => root.focusedWithin(child));
    }

    function childNodes(node: var): var {
        return (node.nodes ?? []).concat(node.floating_nodes ?? []);
    }

    function scan(node: var, fullscreen: bool, found: var): void {
        const inside = fullscreen || (node.fullscreen_mode ?? 0) > 0;
        const label = root.inhibitorLabel(node, inside);

        if (label !== "")
            found.push(label);

        root.childNodes(node).forEach(child => root.scan(child, inside, found));
    }

    Process {
        id: tree

        running: true
        command: ["swaymsg", "-r", "-t", "get_tree"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                try {
                    root.scan(JSON.parse(this.text), false, found);
                } catch (e) {
                }
                root.windowInhibitors = found;
            }
        }
    }

    // logind refuses a delay-mode idle inhibitor ("Delay inhibitors only
    // supported for shutdown and sleep"), so every row naming idle here is a
    // block and there is no mode to filter on.
    Process {
        id: locks

        running: true
        command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "ListInhibitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                let found = [];
                try {
                    found = JSON.parse(this.text).data[0].filter(row => row[0].split(":").indexOf("idle") >= 0).map(row => `${row[1] || "unknown"} (${row[5]})`);
                } catch (e) {
                    found = [];
                }
                root.systemInhibitors = found;
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: true

        onTriggered: root.refresh()
    }
}
