pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.I3
import qs.config

// The session actions, and the confirmation the destructive ones go through.
//
// The accelerators are the mnemonics of the sway `mode $session` block this
// replaces, plus `w` and `q` for the two restarts, which that block had no
// equivalent of.
Singleton {
    id: root

    // Seconds a confirmation waits before going ahead on its own. One value
    // for every action, deliberately: the prompt is a chance to abort, not a
    // question, so a per-action delay would only make it unpredictable.
    readonly property int confirmSeconds: 10

    readonly property var actions: [
        {
            key: "l",
            label: "Lock",
            icon: "lock-key",
            colour: Theme.blue,
            command: "loginctl lock-session",
            confirm: false
        },
        {
            key: "w",
            label: "Reload Sway",
            icon: "arrows-clockwise",
            colour: Theme.teal,
            command: "swaymsg reload",
            confirm: false
        },
        {
            key: "q",
            label: "Restart Quickshell",
            icon: "app-window",
            colour: Theme.green,
            command: "systemctl --user restart quickshell.service",
            confirm: false
        },
        {
            key: "o",
            label: "Log Out",
            icon: "sign-out",
            colour: Theme.yellow,
            command: "exit",
            confirm: true
        },
        {
            key: "s",
            label: "Suspend",
            icon: "moon",
            colour: Theme.mauve,
            command: "systemctl suspend-then-hibernate",
            confirm: true
        },
        {
            key: "h",
            label: "Hibernate",
            icon: "snowflake",
            colour: Theme.sky,
            command: "systemctl hibernate",
            confirm: true
        },
        {
            key: "r",
            label: "Reboot",
            icon: "arrows-clockwise",
            colour: Theme.peach,
            command: "systemctl reboot",
            confirm: true
        },
        {
            key: "p",
            label: "Power Off",
            icon: "power",
            colour: Theme.red,
            command: "systemctl poweroff",
            confirm: true
        }
    ]

    property bool active: false
    property var pending: null

    function show(): void {
        root.active = true;
    }

    function hide(): void {
        root.active = false;
    }

    function toggle(): void {
        if (root.active || root.pending !== null)
            root.cancel();
        else
            root.show();
    }

    // The menu closes before anything is dispatched, so a polkit prompt never
    // has to contend with it for exclusive keyboard focus.
    function choose(action: var): void {
        root.hide();

        if (action.confirm)
            root.pending = action;
        else
            root.dispatch(action);
    }

    function confirm(): void {
        const action = root.pending;
        root.pending = null;

        if (action !== null)
            root.dispatch(action);
    }

    function cancel(): void {
        root.pending = null;
        root.hide();
    }

    function dispatch(action: var): void {
        // `exit` is a sway command; everything else is a program to run.
        I3.dispatch(action.command === "exit" ? "exit" : `exec ${action.command}`);
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.show();
        }

        function close(): void {
            root.cancel();
        }
    }
}
