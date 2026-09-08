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

    // What logind will actually do, asked rather than assumed. On a Secure Boot
    // machine the kernel is in lockdown=integrity, which disables hibernation:
    // CanHibernate and CanSuspendThenHibernate read "na" and /sys/power/disk is
    // [disabled], while every artefact of a hibernate-capable setup -- swap, a
    // resume= in the initramfs -- is still present. The menu used to offer both
    // regardless and logind refused them silently.
    //
    // Probed rather than hardcoded because the machines this config runs on do
    // not have to agree, and the answer can change under one of them when Secure
    // Boot does. The defaults are the conservative reading, so a menu opened
    // before the probe lands offers plain suspend and no hibernate rather than
    // something that will be refused.
    property string canSuspend: "yes"
    property string canHibernate: "na"
    property string canSuspendThenHibernate: "na"

    // "challenge" means logind will ask polkit, which quickshell is the agent
    // for, so it is available in the sense that matters here.
    function allows(answer: string): bool {
        return answer === "yes" || answer === "challenge";
    }

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
            // suspend-then-hibernate where it is offered, plain suspend where
            // it is not -- the label is what the user wants either way.
            command: root.allows(root.canSuspendThenHibernate) ? "systemctl suspend-then-hibernate" : "systemctl suspend",
            confirm: true,
            available: root.allows(root.canSuspend)
        },
        {
            key: "h",
            label: "Hibernate",
            icon: "snowflake",
            colour: Theme.sky,
            command: "systemctl hibernate",
            confirm: true,
            available: root.allows(root.canHibernate)
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
    ].filter(action => action.available !== false)

    // Three methods rather than properties, so `busctl get-property` cannot read
    // them and this is one shell loop instead of three Processes. Each line is
    // `CanSuspend s "yes"`.
    Process {
        running: true
        command: ["sh", "-c", "for m in CanSuspend CanHibernate CanSuspendThenHibernate; do echo $m $(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager $m); done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const answers = {};

                // `text`, not `data` -- the latter is a byte array.
                this.text.trim().split("\n").forEach(line => {
                    const name = line.split(" ")[0];
                    const answer = line.split('"')[1];

                    // A call that failed prints only its name on stdout, which
                    // leaves the conservative default in place.
                    if (name && answer)
                        answers[name] = answer;
                });

                root.canSuspend = answers.CanSuspend ?? root.canSuspend;
                root.canHibernate = answers.CanHibernate ?? root.canHibernate;
                root.canSuspendThenHibernate = answers.CanSuspendThenHibernate ?? root.canSuspendThenHibernate;
            }
        }
    }

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
