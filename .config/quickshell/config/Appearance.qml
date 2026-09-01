pragma Singleton

import Quickshell

// Sizing and typography: the design half of the palette/design split, so a
// theme switch never touches it.
Singleton {
    readonly property string fontFamily: "Cantarell"
    readonly property int fontSize: 20
    readonly property int smallFontSize: 15
    readonly property int headingFontSize: 28
    readonly property int iconSize: 25
    readonly property int trayIconSize: 25

    readonly property int barHeight: 31
}
