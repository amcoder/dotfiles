pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// State for the lock process: the session lock itself, the PAM conversation
// behind it, and the blanking timer.
//
// This lives in its own process (lock.qml, quickshell-lock.service) rather than
// in the shell. If the shell crashed while holding a WlSessionLock, sway would
// keep the session locked -- that is the protocol's security guarantee -- and
// leave a black screen with nothing to type into. Isolating it means every bar
// edit and `systemctl --user restart quickshell` is lock-safe.
Singleton {
    id: root

    // Drives WlSessionLock. Dropping it to false is what unlocks the session.
    property bool locked: true

    // Set from WlSessionLock once the compositor confirms the lock surfaces are
    // up. `lock` waits for the stamp this writes before returning, so a
    // before-sleep hook cannot race a half-mapped surface.
    property bool secure: false

    // Blank the surface after this long with no input, as a substitute for
    // DPMS: a real modeset is trigger #2 for the lockup in
    // .claude/sway-lockup-investigation.md.
    readonly property int blankSeconds: 60
    property bool blanked: false

    readonly property bool busy: pam.active

    property string status: ""
    property bool statusIsError: false

    // Held only between the field's accept and PAM asking for it.
    property string pending: ""

    signal failed

    function tryUnlock(password: string): void {
        if (pam.active || password === "")
            return;

        root.pending = password;
        root.status = "";
        root.statusIsError = false;

        if (!pam.start()) {
            root.pending = "";
            root.report("Could not start authentication", true);
            root.failed();
        }
    }

    function report(message: string, isError: bool): void {
        root.status = message;
        root.statusIsError = isError;
    }

    PamContext {
        id: pam

        // /etc/pam.d/swaylock, which is just an @include of common-auth. Reusing
        // it keeps the emergency lock and this one on the same stack.
        config: "swaylock"

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.pending);
            else if (pam.message !== "")
                root.report(pam.message, pam.messageIsError);
        }

        onCompleted: result => {
            root.pending = "";

            if (result === PamResult.Success) {
                root.locked = false;
                return;
            }

            root.report(result === PamResult.MaxTries ? "Too many attempts" : "Incorrect password", true);
            root.failed();
        }

        // Quickshell does not forward PAM's own failure text, so this is all
        // there is to report -- the same limitation PolkitDialog works around.
        onError: {
            root.pending = "";
            root.report("Authentication error", true);
            root.failed();
        }
    }

    // A stale stamp cannot produce a false positive: `lock` removes it before
    // starting the unit, so its presence always means this run mapped.
    FileView {
        id: stamp

        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-lock.stamp`

        // `lock` removes it before starting the unit, so it is absent on every
        // startup by design and there is nothing to report about that.
        printErrors: false
    }

    onSecureChanged: {
        if (root.secure)
            stamp.setText("locked\n");
    }
}
