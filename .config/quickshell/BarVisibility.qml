pragma Singleton

import QtQuick
import Quickshell
import Quickshell.I3

Singleton {
    id: root

    readonly property string revealCommand: "nop bar reveal"
    readonly property string concealCommand: "nop bar conceal"

    property bool revealed: false

    // Sway cannot report modifier state, so .config/sway/config binds the bare
    // Super keys to `nop` commands and this watches for the binding events.
    I3IpcListener {
        subscriptions: ["binding"]

        onIpcEvent: event => {
            if (event.type !== "binding")
                return;

            const command = JSON.parse(event.data).binding.command;

            if (command === root.revealCommand) {
                root.revealed = true;
                linger.stop();
            } else if (command === root.concealCommand) {
                root.revealed = false;
                linger.stop();
            } else if (root.revealed) {
                linger.restart();
            }
        }
    }

    // Sway forgets the pending release binding as soon as another binding runs,
    // so no conceal event arrives after a $mod combo like $mod+1.
    Timer {
        id: linger

        interval: 500
        onTriggered: root.revealed = false
    }
}
