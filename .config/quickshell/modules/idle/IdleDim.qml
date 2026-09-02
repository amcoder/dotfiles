import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Darkens the output as idle approaches, so the lock is never a surprise.
//
// It is a paint rather than a modeset: `output power off` is trigger #2 for
// the lockup in .claude/sway-lockup-investigation.md, and real DPMS only comes
// back as a per-output opt-in once the kernel question there is settled.
//
// Click-through, because the input that dismisses it should also reach whatever
// is underneath -- the dim is a warning, not a prompt.
PanelWindow {
    id: root

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-idle-dim"

    mask: Region {}

    // Unmapped rather than transparent when idle is not near: an overlay
    // surface that exists costs a composite pass on every frame.
    visible: IdleService.dimmed || shade.opacity > 0

    Rectangle {
        id: shade

        anchors.fill: parent
        color: "black"
        opacity: IdleService.dimmed ? 0.6 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 1000
            }
        }
    }
}
