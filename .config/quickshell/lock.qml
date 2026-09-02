//@ pragma UseQApplication
import QtQml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.lock
import qs.services

// The session lock, deliberately a second entry point and a second process:
// see the comment in services/LockService.qml for why it is not part of the
// shell.
//
// Started by `.local/bin/lock`, which swayidle and `loginctl lock-session`
// both reach. Under QS_LOCK_DEMO it draws the same surface in an ordinary
// overlay window that Escape closes, so all the layout and theme work can be
// done without ever holding a real lock.
ShellRoot {
    id: root

    // Truthiness, not a comparison against "": Quickshell.env() returns null
    // for an unset variable, and `null !== ""` is true -- which silently put
    // every real lock into demo mode, drawing an overlay that Escape dismisses.
    readonly property bool demo: !!Quickshell.env("QS_LOCK_DEMO")

    // Inert in demo mode: a WlSessionLock that is never locked never touches
    // the compositor.
    WlSessionLock {
        id: session

        locked: !root.demo && LockService.locked

        onSecureChanged: LockService.secure = session.secure

        surface: WlSessionLockSurface {
            color: Theme.crust

            LockSurface {
                anchors.fill: parent
            }
        }
    }

    LazyLoader {
        active: root.demo && LockService.locked

        PanelWindow {
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: Theme.crust

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-lock-demo"

            LockSurface {
                anchors.fill: parent

                Keys.onEscapePressed: LockService.locked = false
            }
        }
    }

    // Leave once the compositor has been told to unlock. The unit is
    // Restart=on-failure, so a clean exit stays gone while a crash re-locks.
    Timer {
        running: !LockService.locked
        interval: 250

        onTriggered: Qt.quit()
    }
}
