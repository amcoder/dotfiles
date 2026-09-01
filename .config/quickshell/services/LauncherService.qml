pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3
import qs.config

// The application list, launching, and frecency.
Singleton {
    id: root

    // Must match `set $term` in .config/sway/config: it is what a desktop
    // entry with Terminal=true is run under.
    readonly property string terminal: "alacritty"

    // DesktopEntries only begins its scan once the model is read, and then
    // fills in asynchronously -- so this binding, evaluated when shell.qml
    // instantiates the launcher, is what makes the list ready by the time the
    // keybind is pressed. Reading it for the first time inside show() would
    // open an empty launcher.
    readonly property var applications: DesktopEntries.applications.values

    property bool active: false
    property bool runMode: false

    // Every executable on PATH, for run mode -- what `wofi --show=run` listed.
    property var executables: []

    // { <entry id>: { count, last } }, persisted across restarts.
    property var usage: ({})

    function show(): void {
        root.runMode = false;
        root.active = true;
    }

    function showRun(): void {
        root.runMode = true;
        root.active = true;

        if (root.executables.length === 0)
            scan.running = true;
    }

    function hide(): void {
        root.active = false;
    }

    function toggle(): void {
        if (root.active && !root.runMode)
            root.hide();
        else
            root.show();
    }

    function toggleRun(): void {
        if (root.active && root.runMode)
            root.hide();
        else
            root.showRun();
    }

    function frecency(id: string): real {
        const stat = root.usage[id];
        if (!stat)
            return 0;

        const days = (Date.now() - stat.last) / 86400000;
        const recency = days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : 0.5;
        return stat.count * recency;
    }

    function record(id: string): void {
        const stat = root.usage[id] ?? { count: 0, last: 0 };
        root.usage[id] = { count: stat.count + 1, last: Date.now() };
        root.usageChanged();
        state.setText(JSON.stringify(root.usage));
    }

    function launch(entry: var): void {
        root.hide();
        root.record(entry.id);
        root.exec(entry.command, entry.workingDirectory, entry.runInTerminal);
    }

    function launchAction(entry: var, action: var): void {
        root.hide();
        root.record(entry.id);
        root.exec(action.command, entry.workingDirectory, entry.runInTerminal);
    }

    // Sway runs `exec` through /bin/sh, so the argv has to be quoted back into
    // a command line. Launching through sway rather than as a Process is what
    // keeps apps out of quickshell's control group: `systemctl --user restart
    // quickshell` would otherwise kill everything the launcher started.
    function exec(argv: var, workingDirectory: string, inTerminal: bool): void {
        let command = inTerminal ? [root.terminal, "-e"].concat(argv) : argv;
        let line = command.map(root.quote).join(" ");

        if (workingDirectory !== "")
            line = `cd ${root.quote(workingDirectory)} && ${line}`;

        I3.dispatch(`exec ${line}`);
    }

    function runCommand(line: string): void {
        root.hide();
        I3.dispatch(`exec ${line}`);
    }

    function quote(word: string): string {
        return `'${String(word).split("'").join("'\\''")}'`;
    }

    Process {
        id: scan

        command: ["sh", "-c", 'IFS=:; for dir in $PATH; do [ -d "$dir" ] && find -L "$dir" -maxdepth 1 -type f -executable -printf "%f\\n" 2>/dev/null; done | sort -u']

        stdout: StdioCollector {
            id: scanned

            onStreamFinished: root.executables = scanned.text.split("\n").filter(name => name !== "")
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle();
        }

        function run(): void {
            root.toggleRun();
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

        path: Quickshell.statePath("launcher.json")
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
