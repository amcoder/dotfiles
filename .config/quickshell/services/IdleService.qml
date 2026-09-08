pragma Singleton

import Quickshell
import Quickshell.Io

// The dim that warns the session is about to lock -- and nothing else.
//
// Idle *policy* is swayidle's (../../systemd/user/swayidle.service): it owns
// every timeout, the lock, the screen power-off and logind's Lock, Unlock and
// PrepareForSleep hooks. This service only draws, and is driven over IPC:
//
//     quickshell ipc call idle dim
//     quickshell ipc call idle undim
//
// Keeping the timeouts there rather than here is what leaves one mechanism
// instead of two. It also means both kinds of inhibitor reach the dim and the
// lock without this service knowing anything about either: swayidle respects
// Wayland idle inhibitors compositor-side, and disables all of its timeouts
// while a logind idle inhibitor is held -- so `noidle` and Insomnia's third
// mode work through the ordinary path and need no special case here.
//
// A singleton is created when it is first referenced, so an IPC-only service
// would never register its handler. IdleDim.qml's unconditional `visible`
// binding on `dimmed` is what warms this one; do not make that read
// conditional.
Singleton {
    id: root

    property bool dimmed: false

    IpcHandler {
        target: "idle"

        function dim(): void {
            root.dimmed = true;
        }

        function undim(): void {
            root.dimmed = false;
        }
    }
}
