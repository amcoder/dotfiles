pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Microphone and webcam use, so that something listening or watching when it
// was not expected is visible rather than inferred.
//
// The two halves share nothing but the question they answer. A microphone
// capture is a Pipewire Stream/Input/Audio node, and the *link* feeding it is
// what makes it a microphone: a desktop-audio capture -- a screenshare with
// audio, `wf-recorder -a` -- is the same node type fed by the Audio/Sink
// instead, and a stream with no link at all is connected to nothing.
//
// V4L2 has no such registry, so the webcam half is `camera-watch` reporting
// which processes hold a device node open.
Singleton {
    id: root

    readonly property var micStreams: Pipewire.nodes.values.filter(node => node.type === PwNodeType.AudioInStream && root.capturesDevice(node))
    readonly property var micUsers: root.micStreams.map(node => root.label(node))
    readonly property bool micActive: root.micStreams.length > 0

    property var cameraUsers: []
    readonly property bool cameraActive: root.cameraUsers.length > 0

    function capturesDevice(node: var): bool {
        return Pipewire.links.values.some(link => link.target === node && link.source?.isSink === false);
    }

    function label(node: var): string {
        const props = node.properties ?? {};
        const name = props["application.name"] || node.name || "unknown";
        const pid = props["application.process.id"] ?? "";

        return pid === "" ? name : `${name} (${pid})`;
    }

    // Node type and link ends are readable untracked, so the indicator itself
    // needs no tracker. Naming the app does: an untracked node reports its
    // properties as {} rather than as empty strings.
    PwObjectTracker {
        objects: root.micStreams
    }

    Process {
        id: watcher

        running: true
        command: ["camera-watch"]

        stdout: SplitParser {
            onRead: line => {
                const fields = line.split("\t");
                root.cameraUsers = fields[0] === "active" ? fields.slice(1) : [];
            }
        }
    }

    // A watcher that has died leaves the indicator dark while the camera is
    // on, which is the one way this feature can fail without saying so.
    Timer {
        interval: 10000
        running: !watcher.running
        onTriggered: watcher.running = true
    }
}
