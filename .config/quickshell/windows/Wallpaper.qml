import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// The desktop background, one layer surface per screen, replacing swaybg.
//
// It reproduces swaybg's `center` mode exactly -- the image at its native size,
// centred and clipped, over the theme's crust -- so nothing about the desktop
// changes visibly. That is also why `sourceSize` is left unset: `center` means
// no scaling, and binding it to the screen would silently start resampling.
//
// The layer is Bottom rather than Background, which is where swaybg itself
// sits. Sway draws same-layer surfaces in creation order, and `theme set`
// re-forks swaybg over IPC -- so on the Background layer the solid-colour
// backstop ends up drawn on top of this and the wallpaper disappears until the
// shell restarts. Bottom is above every background surface and below every
// window, whenever each was created.
PanelWindow {
    id: root

    readonly property url wallpaper: Theme.wallpaper ? `${Paths.wallpapers}/${Theme.wallpaper}` : ""
    readonly property int fadeDuration: 300

    // Hand the outgoing image to `previous` and fade the incoming one in over
    // it. Both ends animate because the wallpapers are not all the same size:
    // a smaller incoming image would not cover the one it replaces.
    function crossfade(): void {
        if (fade.running)
            fade.complete();

        previous.source = current.source;
        previous.opacity = 1;
        current.opacity = 0;
        current.source = root.wallpaper;
        root.settle();
    }

    // Anything but Loading is as resolved as it is going to get: Null for a
    // theme that names no wallpaper, Error for one that names a missing file.
    // Both should still fade the old image out rather than strand it.
    function settle(): void {
        if (current.status !== Image.Loading)
            fade.start();
    }

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-wallpaper"

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: Theme.crust

    // Empty deliberately: a layer surface swallows every pointer event in its
    // geometry without a mask, and this one covers the whole output.
    mask: Region {}

    onWallpaperChanged: root.crossfade()

    Item {
        anchors.fill: parent
        clip: true

        Image {
            id: previous

            anchors.centerIn: parent
            asynchronous: true
        }

        Image {
            id: current

            anchors.centerIn: parent
            asynchronous: true
            opacity: 0

            onStatusChanged: root.settle()
        }
    }

    ParallelAnimation {
        id: fade

        NumberAnimation {
            target: previous
            property: "opacity"
            to: 0
            duration: root.fadeDuration
        }

        NumberAnimation {
            target: current
            property: "opacity"
            to: 1
            duration: root.fadeDuration
        }

        // Drop the outgoing pixmap once it is no longer drawn.
        onFinished: previous.source = ""
    }
}
