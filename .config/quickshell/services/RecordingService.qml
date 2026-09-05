pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording, the moving-picture half of the `grimshot` keybinds.
//
// The recorder is a child of the shell rather than something dispatched into
// sway's scope, which is safe because wf-recorder finalises its container on
// SIGTERM and not only on SIGINT -- measured, with a SIGKILL control: SIGINT
// and SIGTERM both leave a `moov` atom, SIGKILL leaves a 48-byte stub. So
// `running = false` saves the recording, and so does a `systemctl --user
// restart quickshell`, which stops a recording rather than truncating it.
Singleton {
    id: root

    readonly property bool active: recorder.running
    property string file: ""
    property int elapsed: 0

    // Left to itself wf-recorder follows the output's refresh rate, which on a
    // 240Hz panel is a 240fps recording that nothing wants: measured over the
    // same 8s capture, the default produced 1853 frames and 1.5MB against 478
    // frames and 396KB at 60.
    readonly property int framerate: 60

    // wf-recorder converts to limited-range YUV but tags the file full-range
    // (yuvj420p, color_range=pc), so a player that honours the tag does not
    // expand it back and every recording came out washed out -- mpv did,
    // VLC guesses limited and so looked right, which is what made it look
    // like a player bug.
    //
    // Its RGB->YUV conversion is also BT.601 whatever the frame size, which
    // for HD is the wrong matrix and disagrees with any player that guesses
    // by resolution. The filter converts with BT.709 so the samples match
    // the tags rather than the tags being bent to match the samples.
    readonly property var colour: ["-p", "color_range=tv", "-p", "colorspace=bt709", "-p", "color_primaries=bt709", "-p", "color_trc=bt709", "-F", "scale=out_color_matrix=bt709"]

    // Set when wf-recorder reports a region it cannot capture, which it does
    // without exiting -- it falls back to 0x0 and records nothing. Without
    // this a drag across two outputs would report a saved file that is empty.
    property bool aborted: false

    // Resolved from xdg-user-dirs below; this is only what stands in until
    // that returns, which it does long before any recording can start.
    property string directory: `${Quickshell.env("HOME")}/Videos/Recordings`

    function toggle(): void {
        if (root.active)
            root.stop();
        else
            root.start();
    }

    function start(): void {
        // A second selection while one is up would leave two slurps fighting
        // over the pointer, and the first recording still unstarted.
        if (root.active || selector.running)
            return;

        selector.running = true;
    }

    function stop(): void {
        recorder.running = false;
    }

    // Colons are legal in a filename and are a nuisance in every app the file
    // is later dragged into, so the stamp is punctuated with dashes.
    function begin(geometry: string): void {
        const now = new Date();
        const pad = n => String(n).padStart(2, "0");
        const stamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;

        root.file = `${root.directory}/recording-${stamp}.mp4`;
        root.elapsed = 0;
        root.aborted = false;

        // `exec` is load-bearing: without it the shell stays as the process
        // group's leader and takes the SIGTERM that stopping sends, leaving
        // wf-recorder orphaned and the container never finalised.
        const args = ["-g", geometry, "-r", String(root.framerate)].concat(root.colour, ["-f", root.file]);

        recorder.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec wf-recorder "$@"', "sh", root.directory].concat(args);
        recorder.running = true;
    }

    function notify(urgency: string, summary: string, body: string): void {
        notifier.command = ["notify-send", "--app-name=Recording", `--urgency=${urgency}`, "--icon=camera-video", summary, body];
        notifier.running = true;
    }

    IpcHandler {
        target: "record"

        function toggle(): void {
            root.toggle();
        }

        function start(): void {
            root.start();
        }

        function stop(): void {
            root.stop();
        }
    }

    Process {
        running: true
        command: ["xdg-user-dir", "VIDEOS"]

        stdout: StdioCollector {
            onStreamFinished: {
                const videos = text.trim();
                if (videos !== "")
                    root.directory = `${videos}/Recordings`;
            }
        }
    }

    Process {
        id: selector

        command: ["record-region"]

        stdout: StdioCollector {
            id: geometry
        }

        // A cancelled slurp exits non-zero and prints nothing, which is the
        // one outcome that must stay silent.
        onExited: exitCode => {
            const region = geometry.text.trim();
            if (exitCode !== 0 || region === "")
                return;

            root.begin(region);
        }
    }

    Process {
        id: recorder

        // Read as it arrives rather than collected, because the message that
        // matters is printed while the process goes on running.
        stderr: SplitParser {
            onRead: line => {
                if (!root.aborted && line.indexOf("Invalid region") !== -1) {
                    root.aborted = true;
                    recorder.running = false;
                }
            }
        }

        onExited: exitCode => {
            const name = root.file.split("/").pop();

            if (root.aborted) {
                discard.command = ["rm", "-f", root.file];
                discard.running = true;
                root.notify("critical", "Recording failed", "The selection has to be inside a single screen.");
            } else if (exitCode === 0) {
                root.notify("normal", "Recording saved", name);
            } else {
                root.notify("critical", "Recording failed", `wf-recorder exited ${exitCode}`);
            }
        }
    }

    Process {
        id: discard
    }

    Process {
        id: notifier
    }

    Timer {
        running: root.active
        interval: 1000
        repeat: true

        onTriggered: root.elapsed++
    }
}
