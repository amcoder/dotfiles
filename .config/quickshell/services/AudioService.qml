pragma Singleton

import Quickshell
import Quickshell.I3
import Quickshell.Io
import Quickshell.Services.Pipewire

// Volume, microphone and device selection, replacing `.local/bin/volume`,
// pamixer and pasystray.
//
// A Pipewire node reports its defaults until something tracks it, so the
// PwObjectTracker below is what makes `volume` and `muted` real values. Node
// *type* is readable untracked, which is why the three lists filter on it
// rather than on `audio` -- filtering on `audio` would leave the tracker with
// nothing to track and the lists empty for good.
Singleton {
    id: root

    readonly property real step: 0.05

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    // Sorted by label: `nodes.values` is in registry order, and a device that
    // re-registers (an HDMI sink following a monitor, say) comes back at the
    // end, reshuffling the list under the cursor.
    readonly property var sinks: root.byLabel(PwNodeType.AudioSink)
    readonly property var sources: root.byLabel(PwNodeType.AudioSource)
    readonly property var streams: Pipewire.nodes.values.filter(node => node.type === PwNodeType.AudioOutStream)

    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property bool micMuted: root.source?.audio?.muted ?? false

    readonly property string icon: {
        if (root.muted)
            return "speaker-slash";
        if (root.volume <= 0)
            return "speaker-none";
        if (root.volume <= 0.5)
            return "speaker-low";
        return "speaker-high";
    }

    function byLabel(type: int): var {
        return Pipewire.nodes.values.filter(node => node.type === type).sort((a, b) => root.label(a).localeCompare(root.label(b)));
    }

    function label(node: var): string {
        if (!node)
            return "";
        return node.nickname || node.description || node.name;
    }

    function streamLabel(node: var): string {
        if (!node)
            return "";
        return node.properties["application.name"] || node.name;
    }

    function setVolume(node: var, value: real): void {
        const audio = node?.audio ?? null;
        if (!audio)
            return;

        audio.volume = Math.min(1, Math.max(0, value));
    }

    function setMuted(node: var, muted: bool): void {
        const audio = node?.audio ?? null;
        if (!audio)
            return;

        audio.muted = muted;
    }

    function toggleNodeMute(node: var): void {
        root.setMuted(node, !(node?.audio?.muted ?? false));
    }

    function setDefaultSink(node: var): void {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node: var): void {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function advanced(): void {
        I3.dispatch("exec pavucontrol");
    }

    // Up and down unmute first, as the script they replace did.
    function adjust(delta: real): void {
        const audio = root.sink?.audio ?? null;
        if (!audio)
            return;

        audio.muted = false;
        root.setVolume(root.sink, audio.volume + delta);
        OsdService.show("volume");
    }

    function up(): void {
        root.adjust(root.step);
    }

    function down(): void {
        root.adjust(-root.step);
    }

    function toggleMute(): void {
        root.toggleNodeMute(root.sink);
        OsdService.show("volume");
    }

    function toggleMicMute(): void {
        root.toggleNodeMute(root.source);
        OsdService.show("microphone");
    }

    PwObjectTracker {
        objects: root.sinks.concat(root.sources, root.streams)
    }

    IpcHandler {
        target: "audio"

        function up(): void {
            root.up();
        }

        function down(): void {
            root.down();
        }

        function mute(): void {
            root.toggleMute();
        }

        function micMute(): void {
            root.toggleMicMute();
        }
    }
}
