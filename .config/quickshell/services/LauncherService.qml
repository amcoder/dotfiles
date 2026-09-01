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
    readonly property var applications: DesktopEntries.applications.values.filter(entry => root.hidden[entry.id] !== true)

    // Entry ids this desktop is not meant to see. Quickshell's DesktopEntries
    // honours NoDisplay but not OnlyShowIn/NotShowIn, and exposes neither key,
    // so the only way to apply them is to read the files again -- which is
    // worth it here: 107 xscreensaver hacks ship OnlyShowIn=MATE and were
    // nearly half the list, alongside the lxqt and GNOME control-centre panels.
    //
    // Scanned once at startup. New .desktop files appear in the model at
    // runtime but are not re-checked, which only matters for a package that
    // installs a desktop-restricted entry mid-session.
    property var hidden: ({})

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

    // The id is the path below applications/ with / turned into -, which is the
    // desktop-file ID from the spec and what DesktopEntry.id holds.
    //
    // The script contains no backslash and no ${...}, deliberately: it lives in
    // a QML template literal, where \/ collapses to / and \[ to [, which
    // silently turns an awk regex into a syntax error and leaves this filtering
    // nothing at all.
    Process {
        id: showIn

        running: true

        command: ["sh", "-c", `
            base=$XDG_DATA_HOME
            [ -n "$base" ] || base=$HOME/.local/share
            dirs=$base:$XDG_DATA_DIRS
            IFS=:
            for dir in $dirs; do
                [ -d "$dir/applications" ] && find "$dir/applications" -name '*.desktop' -type f -print0
            done |
            xargs -0 -r awk -v cur="$XDG_CURRENT_DESKTOP" '
                BEGIN { n = split(cur, want, ":") }
                FNR == 1 {
                    id = FILENAME
                    sub("^.*/applications/", "", id)
                    id = substr(id, 1, length(id) - 8)
                    gsub("/", "-", id)
                    entry = 0
                    done = 0
                }
                substr($0, 1, 1) == "[" { entry = ($0 == "[Desktop Entry]"); next }
                !entry || done { next }
                index($0, "OnlyShowIn=") == 1 {
                    v = ";" substr($0, 12) ";"
                    for (i = 1; i <= n; i++)
                        if (index(v, ";" want[i] ";")) next
                    print id
                    done = 1
                }
                index($0, "NotShowIn=") == 1 {
                    v = ";" substr($0, 11) ";"
                    for (i = 1; i <= n; i++)
                        if (index(v, ";" want[i] ";")) { print id; done = 1; next }
                }
            '
        `]

        stdout: StdioCollector {
            id: restricted

            onStreamFinished: {
                const hidden = {};

                for (const id of restricted.text.split("\n")) {
                    if (id !== "")
                        hidden[id] = true;
                }

                root.hidden = hidden;
            }
        }
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
