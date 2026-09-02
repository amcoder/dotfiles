pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// Idle policy for the session: dim as a warning, then lock.
//
// These timeouts used to be swayidle's. It is now a policy-free adapter that
// only forwards logind's own Lock/Unlock/PrepareForSleep signals, because
// Quickshell 0.3.0 has no logind client and so cannot hear them itself.
//
// Both monitors respect Wayland idle inhibitors, which sway enforces
// compositor-side, so a fullscreen video or wayland-pipewire-idle-inhibit
// holds them off. They cannot see *logind* idle inhibitors -- neither could
// swayidle, measured -- which is why Insomnia is consulted directly below
// rather than through `systemd-inhibit --what=idle`.
Singleton {
    id: root

    readonly property int dimSeconds: 240
    readonly property int lockSeconds: 300

    // Insomnia's third mode asks for idle to be inhibited. Its logind
    // inhibitor never reached swayidle and does not reach an IdleMonitor
    // either; now that idle policy lives in this process, honouring it is one
    // binding.
    readonly property bool inhibited: InsomniaService.mode.inhibitIdle

    property bool dimmed: false

    IdleMonitor {
        enabled: !root.inhibited
        timeout: root.dimSeconds
        respectInhibitors: true

        onIsIdleChanged: root.dimmed = this.isIdle && !root.inhibited
    }

    IdleMonitor {
        enabled: !root.inhibited
        timeout: root.lockSeconds
        respectInhibitors: true

        // `lock` is idempotent and waits for the lock to map, so calling it
        // when already locked is a no-op.
        onIsIdleChanged: {
            if (this.isIdle && !root.inhibited)
                Quickshell.execDetached(["lock"]);
        }
    }

    onInhibitedChanged: {
        if (root.inhibited)
            root.dimmed = false;
    }
}
