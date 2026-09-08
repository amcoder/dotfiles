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
// A level meter is not listening either. pavucontrol opens one `Peak detect`
// stream per source device, marked `stream.monitor`, which a real capture
// leaves unset whether it arrives natively or over the pulse protocol.
//
// V4L2 has no such registry, so the webcam half is `camera-watch` reporting
// which processes hold a device node open.
Singleton {
    id: root

    readonly property var inputStreams: Pipewire.nodes.values.filter(node => node.type === PwNodeType.AudioInStream)
    readonly property var micStreams: root.inputStreams.filter(node => root.capturesDevice(node) && !root.isLevelMeter(node))
    readonly property var micUsers: root.micStreams.map(node => root.label(node)).filter((user, i, users) => users.indexOf(user) === i)
    readonly property bool micActive: root.micStreams.length > 0

    property var cameraUsers: []
    readonly property bool cameraActive: root.cameraUsers.length > 0

    function capturesDevice(node: var): bool {
        return Pipewire.links.values.some(link => link.target === node && link.source?.isSink === false);
    }

    // The property is a Pipewire string, so the string is what it is compared
    // against: a client setting it to "false" would read as truthy.
    function isLevelMeter(node: var): bool {
        return (node.properties ?? {})["stream.monitor"] === "true";
    }

    function label(node: var): string {
        const props = node.properties ?? {};
        const name = props["application.name"] || node.name || "unknown";
        const pid = props["application.process.id"] ?? "";

        return pid === "" ? name : `${name} (${pid})`;
    }

    // An untracked node reports its properties as {} rather than as empty
    // strings, so everything read out of them -- the level-meter test and the
    // app's name alike -- needs the whole candidate set tracked, not just the
    // streams that survive the filter. Node type and link ends are readable
    // untracked, which is what keeps that set small.
    PwObjectTracker {
        objects: root.inputStreams
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
