pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Volume and microphone mute, replacing `.local/bin/volume` and pamixer.
//
// A Pipewire node reports its defaults until something tracks it, so the
// PwObjectTracker below is what makes `volume` and `muted` real values.
Singleton {
    id: root

    readonly property real step: 0.05

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false
    readonly property bool micMuted: root.source?.audio?.muted ?? false

    // Up and down unmute first, as the script they replace did.
    function adjust(delta: real): void {
        const audio = root.sink?.audio ?? null;
        if (!audio)
            return;

        audio.muted = false;
        audio.volume = Math.min(1, Math.max(0, audio.volume + delta));
        OsdService.show("volume");
    }

    function up(): void {
        root.adjust(root.step);
    }

    function down(): void {
        root.adjust(-root.step);
    }

    function toggleMute(): void {
        const audio = root.sink?.audio ?? null;
        if (!audio)
            return;

        audio.muted = !audio.muted;
        OsdService.show("volume");
    }

    function toggleMicMute(): void {
        const audio = root.source?.audio ?? null;
        if (!audio)
            return;

        audio.muted = !audio.muted;
        OsdService.show("microphone");
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
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
