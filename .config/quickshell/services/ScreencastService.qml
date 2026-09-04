pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The source list behind the screencast picker, replacing the wmenu list that
// xdg-desktop-portal-wlr falls back to when no chooser is configured.
//
// `.local/bin/screencast-chooser` is what xdpw actually forks; this only draws
// the choice. The answer goes back over a FIFO the chooser names, because
// `quickshell ipc call` returns as soon as the QML function does and so cannot
// itself wait on a user.
Singleton {
    id: root

    property bool active: false

    // Targets as the chooser described them. `label` is xdpw's own line and is
    // the only thing it will accept back, so it is carried through untouched.
    property var targets: []

    property string fifo: ""

    // The targets arrive as a file rather than as an argument because
    // `quickshell ipc call` *interprets* an argument that looks like JSON
    // instead of passing it through: sent inline, an array came back with its
    // outer brackets stripped and parsed as a bare object, whose `length` is
    // undefined and so filtered down to nothing. A path is not JSON.
    function open(payloadPath: string, fifo: string): void {
        // A second request while one is open would otherwise strand the first
        // chooser on a FIFO nobody writes to, and with it xdpw's waitpid.
        if (root.active)
            root.answer("");

        root.fifo = fifo;
        payload.path = payloadPath;
    }

    function choose(target: var): void {
        root.answer(target.label);
    }

    function cancel(): void {
        root.answer("");
    }

    // An empty line is a cancel: the chooser only echoes a label back to xdpw
    // when it is one xdpw itself produced.
    function answer(label: string): void {
        if (root.fifo === "")
            return;

        // Writing to the FIFO blocks until its reader is there. The chooser
        // opens its end before asking, so that is already true -- the timeout
        // only covers a chooser that died while the picker was open.
        writer.command = ["timeout", "5", "sh", "-c", 'printf "%s\\n" "$1" > "$2"', "sh", label, root.fifo];
        writer.running = true;

        root.fifo = "";
        root.active = false;
        root.targets = [];

        // Cleared so the next request always changes the path, which is what
        // makes FileView load again rather than reuse what it already has.
        payload.path = "";
    }

    // A load that never yields usable targets still has to answer the FIFO:
    // the chooser is blocked on it, and xdpw is blocked on the chooser.
    FileView {
        id: payload

        path: ""
        watchChanges: false
        printErrors: false

        onLoaded: {
            let parsed = [];

            try {
                parsed = JSON.parse(payload.text());
            } catch (error) {
                parsed = [];
            }

            if (!Array.isArray(parsed) || parsed.length === 0) {
                root.answer("");
                return;
            }

            root.targets = parsed;
            root.active = true;
        }

        onLoadFailed: root.answer("")
    }

    Process {
        id: writer
    }

    IpcHandler {
        target: "screencast"

        function open(payloadPath: string, fifo: string): void {
            root.open(payloadPath, fifo);
        }

        function close(): void {
            root.cancel();
        }
    }
}
