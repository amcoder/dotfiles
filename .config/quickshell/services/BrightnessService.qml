pragma Singleton

import Quickshell
import Quickshell.Io

// The backlight, replacing `.local/bin/brightness` and brightnessctl.
//
// `/sys/class/backlight/*/brightness` is root:video 0664 and the user is in
// `video`, so the shell writes it directly. The write must not be atomic:
// FileView's default write-to-temp-then-rename is refused by sysfs.
Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int level: 0

    readonly property bool available: root.max > 0
    readonly property real fraction: root.available ? root.level / root.max : 0

    // brightnessctl's `10%`, which is a tenth of the panel's whole range.
    readonly property int step: Math.max(1, Math.round(root.max / 10))

    // The floor is one raw unit rather than zero: a panel at zero is
    // indistinguishable from a session that has died.
    function set(value: int): void {
        if (!root.available)
            return;

        root.level = Math.min(root.max, Math.max(1, value));
        current.setText(String(root.level));
        OsdService.show("brightness");
    }

    function up(): void {
        root.set(root.level + root.step);
    }

    function down(): void {
        root.set(root.level - root.step);
    }

    Process {
        running: true
        command: ["sh", "-c", "ls -1 /sys/class/backlight 2>/dev/null | head -1"]

        stdout: StdioCollector {
            id: probe

            onStreamFinished: {
                const name = probe.text.trim();
                root.device = name === "" ? "" : `/sys/class/backlight/${name}`;
            }
        }
    }

    FileView {
        id: ceiling

        path: root.device === "" ? "" : `${root.device}/max_brightness`
        blockLoading: true

        onLoaded: root.max = parseInt(ceiling.text()) || 0
    }

    // Watched, so the firmware's own hotkeys move the level with it.
    FileView {
        id: current

        path: root.device === "" ? "" : `${root.device}/brightness`
        blockLoading: true
        watchChanges: true
        atomicWrites: false

        onFileChanged: current.reload()

        // The optimistic `level` in set() is a lie if the write was refused,
        // and a refused write leaves the file unchanged, so nothing else would
        // ever correct it.
        onSaveFailed: current.reload()

        onLoaded: root.level = parseInt(current.text()) || 0
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            root.up();
        }

        function down(): void {
            root.down();
        }
    }
}
