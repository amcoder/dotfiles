pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3
import qs.config

// The open windows, in most-recently-used order.
//
// Quickshell.I3 exposes only workspace and output events, so the window list
// comes from a `swaymsg -t subscribe` of its own. Every event triggers a fresh
// `get_tree` rather than a patch: sway's per-container `focus` arrays already
// hold the focus history -- walking children in that order yields the MRU list
// directly, so there is nothing to maintain by hand and no way to drift.
Singleton {
    id: root

    property bool active: false
    property var windows: []

    function show(): void {
        if (root.windows.length === 0)
            return;

        root.active = true;
    }

    function hide(): void {
        root.active = false;
    }

    function toggle(): void {
        if (root.active)
            root.hide();
        else
            root.show();
    }

    function focusWindow(window: var): void {
        root.hide();
        I3.dispatch(`[con_id=${window.id}] focus`);
    }

    function closeWindow(window: var): void {
        I3.dispatch(`[con_id=${window.id}] kill`);
    }

    function collect(node: var, workspace: var, out: var): void {
        const here = node.type === "workspace" ? node : workspace;
        const children = (node.nodes ?? []).concat(node.floating_nodes ?? []);

        if (children.length === 0) {
            if (node.type !== "con" && node.type !== "floating_con")
                return;

            const properties = node.window_properties ?? {};
            out.push({
                id: node.id,
                appId: node.app_id ?? properties.instance ?? properties.class ?? "",
                title: node.name ?? "",
                focused: node.focused === true,
                workspace: here ? here.num : -1,
                scratchpad: here ? here.name === "__i3_scratch" : false
            });
            return;
        }

        const byId = {};
        for (const child of children)
            byId[child.id] = child;

        const taken = {};
        for (const id of node.focus ?? []) {
            if (byId[id] === undefined)
                continue;

            taken[id] = true;
            root.collect(byId[id], here, out);
        }

        for (const child of children) {
            if (taken[child.id] !== true)
                root.collect(child, here, out);
        }
    }

    IpcHandler {
        target: "windows"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.show();
        }

        function close(): void {
            root.hide();
        }
    }

    // Coalesces the burst of events a single action can produce.
    Timer {
        id: refresh

        interval: 40

        onTriggered: tree.running = true
    }

    Process {
        id: tree

        running: true
        command: ["swaymsg", "-r", "-t", "get_tree"]

        stdout: StdioCollector {
            id: collected

            onStreamFinished: {
                try {
                    const out = [];
                    root.collect(JSON.parse(collected.text), null, out);
                    root.windows = out;
                } catch (error) {
                    root.windows = [];
                }
            }
        }
    }

    Process {
        running: true
        command: ["swaymsg", "-r", "-t", "subscribe", "-m", '["window","workspace"]']

        stdout: SplitParser {
            onRead: line => {
                try {
                    if (JSON.parse(line).change !== undefined)
                        refresh.restart();
                } catch (error) {
                }
            }
        }
    }
}
