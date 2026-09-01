pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var modes: [
        {
            icon: "moon",
            color: Theme.surface1,
            inhibitSleep: false,
            inhibitIdle: false
        },
        {
            icon: "eye",
            color: Theme.yellow,
            inhibitSleep: true,
            inhibitIdle: false
        },
        {
            icon: "sun",
            color: Theme.peach,
            inhibitSleep: true,
            inhibitIdle: true
        }
    ]

    readonly property var mode: root.modes[state.modeIndex]

    function cycle() {
        state.modeIndex = (state.modeIndex + 1) % root.modes.length;
    }

    PersistentProperties {
        id: state

        reloadableId: "insomnia"

        property int modeIndex: 0
    }

    // logind hands out locks as file descriptors, which QML can't hold open, so
    // each lock lives for as long as its process does.
    Process {
        running: root.mode.inhibitSleep && !root.mode.inhibitIdle
        command: ["systemd-inhibit", "--what=shutdown:sleep", "--who=insomnia", "--why=user", "sleep", "infinity"]
    }

    Process {
        running: root.mode.inhibitIdle
        command: ["systemd-inhibit", "--what=shutdown:sleep:idle", "--who=insomnia", "--why=user", "sleep", "infinity"]
    }
}
