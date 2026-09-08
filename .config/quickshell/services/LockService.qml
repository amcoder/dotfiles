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

    readonly property bool busy: pam.active

    property string status: ""
    property bool statusIsError: false

    // Held only between the field's accept and PAM asking for it.
    property string pending: ""

    signal failed

    // What makes `systemctl --user stop quickshell-lock.service` an unlock
    // rather than a stranding. Dropping `locked` is what sends
    // unlock_and_destroy; a signal cannot, and the SIGTERM systemd would send
    // instead leaves the compositor holding an abandoned lock with no client
    // attached -- a screen with nothing to type into. The unit's ExecStop
    // calls this first, so the process is gone before any signal is sent.
    IpcHandler {
        target: "lock"

        function unlock(): void {
            root.locked = false;
        }
    }

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

    // Tell logind the session is locked, so LockedHint follows reality whichever
    // path locked it. Nothing here consumes it yet; it is set because anything
    // added later that asks logind whether the session is locked would
    // otherwise be told "no" with the lock screen up.
    //
    // `session/auto` is the right object even though this runs as a user unit
    // with no session of its own and no XDG_SESSION_ID in its environment:
    // logind falls back to the user's display session. Measured -- it resolves
    // to the same session id from a user unit as from a login shell, and the
    // write needs no polkit. execDetached rather than a Process because the
    // client quits 250ms after unlocking and would tear a Process down with it.
    //
    // A killed client leaves the hint set, which is correct: the compositor goes
    // on holding an abandoned lock, so the session really is still locked.
    property bool hinted: false

    function setLockedHint(value: bool): void {
        root.hinted = value;
        Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetLockedHint", "b", value ? "true" : "false"]);
    }

    onLockedChanged: {
        // Only clear a hint this process set, so demo mode -- which never goes
        // secure -- cannot report an unlock that never happened.
        if (!root.locked && root.hinted)
            root.setLockedHint(false);
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
        if (!root.secure)
            return;

        stamp.setText("locked\n");
        root.setLockedHint(true);
    }
}
