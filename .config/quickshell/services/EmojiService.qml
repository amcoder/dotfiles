pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import qs.config

// The emoji list and its frecency, replacing bemoji.
//
// The database is a vendored copy of the `<glyph> <name>` list bemoji used to
// download, kept in the repo alongside the icons for the same reason: nothing
// should have to fetch it on a fresh machine.
Singleton {
    id: root

    property bool active: false

    // { <glyph>: { count, last } }, persisted across restarts.
    property var usage: ({})

    readonly property var entries: {
        const out = [];

        for (const line of database.text().split("\n")) {
            const split = line.indexOf(" ");
            if (split <= 0)
                continue;

            out.push({
                glyph: line.slice(0, split),
                name: line.slice(split + 1)
            });
        }

        return out;
    }

    function show(): void {
        root.active = true;
    }

    function hide(): void {
        root.active = false;
    }

    function toggle(): void {
        root.active = !root.active;
    }

    function frecency(glyph: string): real {
        const stat = root.usage[glyph];
        if (!stat)
            return 0;

        const days = (Date.now() - stat.last) / 86400000;
        const recency = days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : 0.5;
        return stat.count * recency;
    }

    function record(glyph: string): void {
        const stat = root.usage[glyph] ?? { count: 0, last: 0 };
        root.usage[glyph] = { count: stat.count + 1, last: Date.now() };
        root.usageChanged();
        state.setText(JSON.stringify(root.usage));
    }

    // MUST be called straight from the input handler that chose the emoji.
    //
    // Qt takes the Wayland selection using the seat's last input serial, so a
    // clipboard write made from a timer -- or from anywhere the surface is
    // merely focused, with no recent key or click -- updates Qt's own copy and
    // nothing else, and `wl-paste` goes on reporting the old contents. Setting
    // it inside the handler is what makes the write real. Ownership then lasts
    // as long as the shell process, surviving the picker closing, which is one
    // fewer forked helper than `wl-copy` needed.
    function copy(glyph: string): void {
        Quickshell.clipboardText = glyph;
        root.record(glyph);
        root.hide();
    }

    // Paste is dispatched through sway rather than run as a child process, for
    // the same reason the launcher dispatches `exec`: a quickshell child dies
    // with the shell on every restart. The delay is the focus handover -- the
    // keystroke has to land in the window the picker was covering, and the
    // overlay is still being unmapped when `copy()` returns.
    function paste(): void {
        I3.dispatch("exec sh -c 'sleep 0.1; wtype -M ctrl -k v -m ctrl'");
    }

    FileView {
        id: database

        path: Paths.emoji
        watchChanges: false
        preload: true
    }

    IpcHandler {
        target: "emoji"

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

    FileView {
        id: state

        path: Quickshell.statePath("emoji.json")
        watchChanges: false
        printErrors: false

        onLoaded: {
            try {
                root.usage = JSON.parse(state.text()) ?? {};
            } catch (error) {
                root.usage = {};
            }
        }

        onLoadFailed: root.usage = {}
    }
}
