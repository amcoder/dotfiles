pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Colours come from palette.json, written by `theme apply`. The file is
    // watched, so a theme switch repaints the bar without a restart. The
    // fallbacks are Catppuccin Macchiato, used until the file loads.
    readonly property var fallback: ({
            rosewater: "#f4dbd6",
            flamingo: "#f0c6c6",
            pink: "#f5bde6",
            mauve: "#c6a0f6",
            red: "#ed8796",
            maroon: "#ee99a0",
            peach: "#f5a97f",
            yellow: "#eed49f",
            green: "#a6da95",
            teal: "#8bd5ca",
            sky: "#91d7e3",
            sapphire: "#7dc4e4",
            blue: "#8aadf4",
            lavender: "#b7bdf8",
            text: "#cad3f5",
            subtext1: "#b8c0e0",
            subtext0: "#a5adcb",
            overlay2: "#939ab7",
            overlay1: "#8087a2",
            overlay0: "#6e738d",
            surface2: "#5b6078",
            surface1: "#494d64",
            surface0: "#363a4f",
            base: "#24273a",
            mantle: "#1e2030",
            crust: "#181926"
        })

    property var loaded: null

    // Set by ThemePicker while browsing, so a highlighted row previews itself
    // on the real bar. Cleared when the picker closes.
    property var preview: null

    readonly property var palette: root.preview ?? (root.loaded ? root.loaded.colors : root.fallback)

    readonly property color rosewater: root.palette.rosewater ?? root.fallback.rosewater
    readonly property color flamingo: root.palette.flamingo ?? root.fallback.flamingo
    readonly property color pink: root.palette.pink ?? root.fallback.pink
    readonly property color mauve: root.palette.mauve ?? root.fallback.mauve
    readonly property color red: root.palette.red ?? root.fallback.red
    readonly property color maroon: root.palette.maroon ?? root.fallback.maroon
    readonly property color peach: root.palette.peach ?? root.fallback.peach
    readonly property color yellow: root.palette.yellow ?? root.fallback.yellow
    readonly property color green: root.palette.green ?? root.fallback.green
    readonly property color teal: root.palette.teal ?? root.fallback.teal
    readonly property color sky: root.palette.sky ?? root.fallback.sky
    readonly property color sapphire: root.palette.sapphire ?? root.fallback.sapphire
    readonly property color blue: root.palette.blue ?? root.fallback.blue
    readonly property color lavender: root.palette.lavender ?? root.fallback.lavender
    readonly property color text: root.palette.text ?? root.fallback.text
    readonly property color subtext1: root.palette.subtext1 ?? root.fallback.subtext1
    readonly property color subtext0: root.palette.subtext0 ?? root.fallback.subtext0
    readonly property color overlay2: root.palette.overlay2 ?? root.fallback.overlay2
    readonly property color overlay1: root.palette.overlay1 ?? root.fallback.overlay1
    readonly property color overlay0: root.palette.overlay0 ?? root.fallback.overlay0
    readonly property color surface2: root.palette.surface2 ?? root.fallback.surface2
    readonly property color surface1: root.palette.surface1 ?? root.fallback.surface1
    readonly property color surface0: root.palette.surface0 ?? root.fallback.surface0
    readonly property color base: root.palette.base ?? root.fallback.base
    readonly property color mantle: root.palette.mantle ?? root.fallback.mantle
    readonly property color crust: root.palette.crust ?? root.fallback.crust

    readonly property color barBackground: base
    readonly property color barStatusline: text
    readonly property color barSeparator: blue

    readonly property color popupBackground: mantle
    readonly property color popupBorder: surface1
    readonly property color popupText: text
    readonly property color popupSubtext: subtext0
    readonly property color popupHover: surface0
    readonly property color popupSelection: surface1

    readonly property color overlayScrim: Qt.rgba(crust.r, crust.g, crust.b, 0.65)

    // The theme's wallpaper, a bare filename under Paths.wallpapers. Unlike the
    // colours it does not follow `preview`: arrowing through the picker would
    // decode a full-resolution image per row, so it changes on commit like
    // everything else outside quickshell.
    readonly property string wallpaper: root.loaded?.wallpaper ?? ""

    FileView {
        id: view

        path: `${Paths.config}/quickshell/palette.json`
        watchChanges: true

        onFileChanged: view.reload()

        onLoaded: {
            try {
                root.loaded = JSON.parse(view.text());
            } catch (error) {
                root.loaded = null;
            }
        }

        onLoadFailed: root.loaded = null
    }
}
