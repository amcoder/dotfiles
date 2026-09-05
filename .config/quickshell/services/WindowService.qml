pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3
import qs.config

// The open windows, in most-recently-used order, and the Super+Tab cycle over
// them.
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

    // -- Super+Tab cycling --------------------------------------------------
    //
    // `cycle` is a snapshot of the order taken when the gesture starts rather
    // than a view of `windows`: committing a choice re-sorts the MRU list, and
    // a live view would scramble the indices under the picker.
    //
    // Nothing is drawn until `revealed`. A tap of Super+Tab switches to the
    // last window with no picker appearing at all, so the surface maps at once
    // -- it has to, to catch the Super release, which sway cannot report (see
    // modules/switcher/WindowCycler.qml) -- and paints only once the modifier
    // has been held past `revealDelay`.
    property var cycle: []
    property int index: 0
    property bool revealed: false

    readonly property bool cycling: root.cycle.length > 0

    // identifier -> a PNG of that window, filled in progressively while the
    // picker is open. `window-thumbs` keeps them between cycles, so a later
    // cycle draws the previous picture of each window immediately.
    property var thumbnails: ({})

    // Long enough that a deliberate tap never flashes the picker, short enough
    // that holding the modifier feels like the picker opened on its own. The
    // release cannot reach the shell sooner than ~45ms after the keypress
    // anyway -- the cost of `quickshell ipc call` plus mapping the surface --
    // so a tap is committed well before this fires.
    readonly property int revealDelay: 180

    function step(delta: int): void {
        if (!root.cycling) {
            root.beginCycle(delta);
            return;
        }

        const count = root.cycle.length;
        root.index = (root.index + delta + count) % count;

        // A second press is the user steering the picker, so there is nothing
        // left to wait for.
        root.revealCycle();
    }

    // Clamped where `step` wraps: Tab is a ring, but falling off the bottom row
    // of a grid onto the top one reads as the selection jumping at random.
    function select(at: int): void {
        root.index = Math.max(0, Math.min(at, root.cycle.length - 1));
    }

    function beginCycle(delta: int): void {
        // Sway is already holding the keyboard in the cycle mode by the time
        // this runs, so every path out of here has to hand it back.
        if (root.windows.length < 2) {
            root.endCycle();
            return;
        }

        root.cycle = root.windows;

        // Index 0 is the focused window, so one step along is what a bare tap
        // switches to -- which is what makes it an alt-tab.
        root.index = delta > 0 ? 1 : root.cycle.length - 1;
        reveal.restart();
    }

    // Opened by a click rather than by holding a modifier: there is nothing to
    // hold, so the picker is drawn at once and the next press is what commits,
    // the way releasing Super does.
    function toggleCycle(): void {
        if (root.cycling) {
            root.commitCycle();
            return;
        }

        root.beginCycle(1);

        if (root.cycling)
            root.revealCycle();
    }

    function revealCycle(): void {
        reveal.stop();

        if (root.revealed)
            return;

        root.revealed = true;
        root.captureThumbnails();
    }

    function commitCycle(): void {
        const window = root.cycle[root.index];
        root.endCycle();

        if (window !== undefined)
            I3.dispatch(`[con_id=${window.id}] focus`);
    }

    function endCycle(): void {
        reveal.stop();

        // `thumbs` is deliberately left running. A gesture is usually over
        // before the batch is -- captures land between 130 and 600ms -- and
        // killing it meant the windows that capture last never refreshed at
        // all: their cached thumbnail was reported again next time, recaptured,
        // and killed again, so they were stuck on the first picture ever taken
        // of them. Letting the batch finish is what keeps the cache current.
        root.cycle = [];
        root.index = 0;
        root.revealed = false;

        // Sway leaves the cycle mode only when told to, and this is the only
        // thing that tells it.
        I3.dispatch("mode default");
    }

    function captureThumbnails(): void {
        const args = [];

        // Most-recently-used order, which is the order the captures complete in
        // and so the order the previews appear in.
        for (const window of root.cycle) {
            if (window.identifier !== "")
                args.push(`${window.identifier}:${window.width}`);
        }

        if (args.length === 0)
            return;

        // A batch still in flight from the last cycle is capturing these same
        // windows and its results are newer than a restart's would be, so it is
        // left alone rather than taken over.
        if (thumbs.running)
            return;

        thumbs.command = ["window-thumbs"].concat(args);
        thumbs.running = true;
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
            const rect = node.rect ?? {};
            out.push({
                id: node.id,
                // The compositor's ext_foreign_toplevel_list_v1 identifier,
                // which is what `grim -T` captures a thumbnail by.
                identifier: node.foreign_toplevel_identifier ?? "",
                width: rect.width ?? 0,
                height: rect.height ?? 0,
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

        function next(): void {
            root.step(1);
        }

        function previous(): void {
            root.step(-1);
        }

        function cycle(): void {
            root.toggleCycle();
        }

        function cancel(): void {
            root.endCycle();
        }
    }

    Timer {
        id: reveal

        interval: root.revealDelay

        onTriggered: root.revealCycle()
    }

    Process {
        id: thumbs

        stdout: SplitParser {
            onRead: line => {
                const split = line.indexOf(" ");
                if (split < 0)
                    return;

                // Replaced rather than assigned into: mutating the existing
                // object is not a property change, and no binding would see it.
                const next = Object.assign({}, root.thumbnails);
                next[line.slice(0, split)] = line.slice(split + 1);
                root.thumbnails = next;
            }
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
