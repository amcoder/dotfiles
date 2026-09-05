import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.windows

// The Super+Tab window cycler: large previews of every open window, in
// most-recently-used order, held open for as long as the modifier is.
//
// Sway hands the keyboard to this surface on the first press and then stays out
// of the way -- the $cycle mode in .config/sway/config binds almost nothing --
// because sway cannot report the Super release itself. A --release binding is
// armed when its own key goes down and discarded by the next key press, so the
// release that follows a Tab is never seen, in any mode and with or without the
// modifier in the combo. What can see it is whatever holds the keyboard, so this
// surface maps when the gesture starts rather than when it is first drawn, and
// takes the release as an ordinary key event.
//
// One race is inherent to that: the release is only delivered once the surface
// is focused, ~45ms after the keypress, of which ~37ms is the cost of
// `quickshell ipc call`. A tap cannot release Super before it has released Tab,
// so the margin holds -- but a release missed inside that window leaves the
// picker open, which Escape or a click outside clears.
Scope {
    id: root

    // How much of the screen the card takes, and how tall one row of previews
    // is allowed to be. The cell's width follows from its height.
    readonly property real widthFraction: 0.94
    readonly property real heightFraction: 0.55

    // At least this many windows are on screen at once: a strip whose cell is
    // wide enough to hide its neighbours has nothing to slide.
    readonly property int minVisible: 3

    // Everything but the preview: the cell's own margins, and the row of icon,
    // title and workspace below it.
    readonly property int cellMargins: 24
    readonly property int labelHeight: 84

    // The preview box is squarer than a screen because what goes in it is a
    // window: tiled thirds and halves of an ultrawide are nearer square than
    // 16:9, and a wider box letterboxes every one of them.
    readonly property real previewAspect: 3 / 2

    readonly property int slideDuration: 180

    function icon(window: var): string {
        const entry = DesktopEntries.heuristicLookup(window.appId);
        const name = entry ? entry.icon : window.appId;
        return Quickshell.iconPath(name, "preferences-system-windows");
    }

    function place(window: var): string {
        return window.scratchpad ? "scratchpad" : `workspace ${window.workspace}`;
    }

    ModalOverlay {
        id: overlay

        readonly property var selected: WindowService.cycle[WindowService.index] ?? null

        readonly property int available: Math.round((overlay.screen ? overlay.screen.width : 1920) * root.widthFraction)

        // One row, sized from the screen's height and then capped so that
        // `minVisible` windows still fit across it.
        readonly property int cellWidth: {
            const room = (overlay.screen ? overlay.screen.height : 1080) * root.heightFraction;
            const fromHeight = (room - root.labelHeight) * root.previewAspect + root.cellMargins;
            return Math.round(Math.min(fromHeight, (overlay.available - overlay.padding * 2) / root.minVisible));
        }

        readonly property int cellHeight: Math.round((overlay.cellWidth - root.cellMargins) / root.previewAspect) + root.labelHeight

        // The preview box in physical pixels, which is what the thumbnails are
        // decoded at. `sourceSize` is in logical pixels and Qt does not scale it
        // by the screen's ratio, so a box measured in logical units alone would
        // decode at half resolution on a scaled screen and look soft.
        readonly property int previewWidth: Math.round((overlay.cellWidth - root.cellMargins) * (overlay.screen ? overlay.screen.devicePixelRatio : 1))
        readonly property int previewHeight: Math.round(overlay.previewWidth / root.previewAspect)

        namespaceSuffix: "window-cycler"

        visible: WindowService.cycling
        drawn: WindowService.revealed
        closeOnClickOutside: true
        cardWidth: overlay.available
        focusItem: nav

        onDismissed: WindowService.endCycle()

        // Set before the card is ever drawn, so the strip is already sitting on
        // the selection when it appears rather than sliding onto it.
        onOpened: {
            wheel.accumulated = 0;
            strip.currentIndex = WindowService.index;
        }

        // The index lives in the service, which is what the first keypress
        // reaches over IPC, and is assigned here rather than bound: ListView
        // writes to `currentIndex` itself, and a binding it clobbered once would
        // stay broken. Assigning it is also what starts the slide.
        Connections {
            target: WindowService

            function onIndexChanged(): void {
                strip.currentIndex = WindowService.index;
            }
        }

        Item {
            id: nav

            // Focus only; the card's own children draw everything.
            width: 0
            height: 0

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Tab:
                    WindowService.step(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                    break;
                case Qt.Key_Backtab:
                    WindowService.step(-1);
                    break;
                case Qt.Key_Right:
                    WindowService.step(1);
                    break;
                case Qt.Key_Left:
                    WindowService.step(-1);
                    break;
                case Qt.Key_Home:
                    WindowService.select(0);
                    break;
                case Qt.Key_End:
                    WindowService.select(WindowService.cycle.length - 1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    WindowService.commitCycle();
                    break;
                case Qt.Key_Escape:
                    WindowService.endCycle();
                    break;
                default:
                    return;
                }

                event.accepted = true;
            }

            Keys.onReleased: event => {
                // The whole gesture ends here: sway cannot tell the shell that
                // Super came up, so this release is the commit.
                if (event.key !== Qt.Key_Meta)
                    return;

                WindowService.commitCycle();
                event.accepted = true;
            }
        }

        Item {
            width: parent.width
            implicitHeight: heading.implicitHeight

            // Centred, because what it names is the cell in the middle of the
            // strip directly below it.
            Column {
                id: heading

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width * 0.5, overlay.cellWidth)
                spacing: 1

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: overlay.selected !== null
                        width: Appearance.launcherIconSize
                        height: Appearance.launcherIconSize
                        sourceSize.width: Appearance.launcherIconSize
                        sourceSize.height: Appearance.launcherIconSize
                        smooth: true
                        source: overlay.selected ? root.icon(overlay.selected) : ""
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, heading.width - Appearance.launcherIconSize - 12)
                        text: overlay.selected ? overlay.selected.title : ""
                        color: Theme.popupText
                        elide: Text.ElideRight
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.headingFontSize
                    }
                }

                Text {
                    width: parent.width
                    text: overlay.selected ? `${overlay.selected.appId} · ${root.place(overlay.selected)}` : ""
                    color: Theme.popupSubtext
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: heading.verticalCenter
                text: "Release Super to switch · Esc to cancel"
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }

        // The strip is wrapped so the wheel handler sits on an ordinary Item.
        // Declared inside the ListView it would be added to `flickableData` and
        // parented to the content item, which moves with the content.
        Item {
            width: parent.width
            height: overlay.cellHeight

            // Scrolling moves the selection, because the selection is pinned to
            // the centre and there is no free scroll to be had. Clamped rather
            // than wrapped as Tab is: a wheel that rolls off the end of a list
            // stops there.
            //
            // A MouseArea over the list rather than a WheelHandler beside it:
            // measured against a virtual pointer, a WheelHandler on the item
            // wrapping the ListView never fired once, while this sees every
            // event. `Qt.NoButton` is what lets a press through to the cell
            // underneath, so clicking still picks a window.
            MouseArea {
                id: wheel

                property real accumulated: 0

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                z: 1

                // A notch is 120 units; a touchpad sends a stream of small ones,
                // which is what the accumulator is for. Scrolling down reads as
                // negative and moves towards the next window. A thumb wheel
                // reads as horizontal, which on a strip is the same gesture and
                // carries the same sign.
                onWheel: event => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    if (delta === 0)
                        return;

                    wheel.accumulated += delta;

                    const steps = Math.trunc(wheel.accumulated / 120);
                    if (steps === 0)
                        return;

                    wheel.accumulated -= steps * 120;
                    WindowService.select(WindowService.index - steps);
                }
            }

            // One row that slides under a fixed centre rather than a grid the
            // selection moves around inside: StrictlyEnforceRange with the highlight
            // range pinned to the middle of the view is what keeps the selected
            // window in the centre of the screen, and animating its way there is the
            // whole of the slide.
            ListView {
                id: strip

                anchors.fill: parent
                orientation: ListView.Horizontal
                clip: true

                // Keyboard-driven; a flick would fight the enforced range.
                interactive: false

                preferredHighlightBegin: (strip.width - overlay.cellWidth) / 2
                preferredHighlightEnd: (strip.width + overlay.cellWidth) / 2
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: root.slideDuration
                highlightMoveVelocity: -1

                model: WindowService.cycle

                delegate: Item {
                    id: cell

                    required property int index
                    required property var modelData

                    readonly property bool current: cell.ListView.isCurrentItem
                    readonly property string thumbnail: WindowService.thumbnails[cell.modelData.identifier] ?? ""

                    // The capture currently on screen, which lags `thumbnail` by
                    // however long the incoming one takes to decode.
                    property url shown: ""

                    width: overlay.cellWidth
                    height: overlay.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 6
                        color: cell.current ? Theme.popupSelection : Theme.base
                        border.color: cell.current ? Theme.blue : Theme.surface1
                        border.width: 1

                        Rectangle {
                            id: shot

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            height: Math.round(width / root.previewAspect)
                            radius: 4
                            color: Theme.crust
                            clip: true

                            // Fitted rather than cropped: a window's shape is part
                            // of recognising it.
                            //
                            // Two images rather than one, because a cell holding a
                            // picture must not blank while the next capture of the
                            // same window decodes -- the fallback icon underneath
                            // would show through, and a cycle refreshes every cell.
                            // `pending` loads out of sight and hands over only once
                            // it is ready; `preview` then takes it from the pixmap
                            // cache, which is why it loads synchronously and so
                            // never passes through a Loading frame of its own.
                            Image {
                                id: preview

                                anchors.fill: parent
                                anchors.margins: 1
                                source: cell.shown
                                fillMode: Image.PreserveAspectFit
                                asynchronous: false
                                smooth: true
                                sourceSize.width: overlay.previewWidth
                                sourceSize.height: overlay.previewHeight
                            }

                            Image {
                                id: pending

                                visible: false
                                asynchronous: true
                                source: cell.thumbnail === "" ? "" : `file://${cell.thumbnail}`

                                // Matched to `preview` exactly: a different size is
                                // a different key in the pixmap cache, and the
                                // handover would decode from disk all over again.
                                sourceSize.width: overlay.previewWidth
                                sourceSize.height: overlay.previewHeight

                                onStatusChanged: {
                                    if (pending.status === Image.Ready)
                                        cell.shown = pending.source;
                                }
                            }

                            // Whatever grim could not capture -- it refuses some
                            // clients' buffers outright, and a cached thumbnail can
                            // have been pruned under us -- keeps the app icon. It
                            // means "there is no picture of this window", never
                            // "the picture has not decoded yet": showing it while
                            // one loads flashes an icon over every cell each time a
                            // cycle refreshes them.
                            Image {
                                anchors.centerIn: parent
                                visible: preview.status !== Image.Ready && pending.status !== Image.Loading
                                width: 56
                                height: 56
                                sourceSize.width: 56
                                sourceSize.height: 56
                                smooth: true
                                source: root.icon(cell.modelData)
                            }
                        }

                        Image {
                            id: badge

                            anchors.left: parent.left
                            anchors.top: shot.bottom
                            anchors.leftMargin: 10
                            anchors.topMargin: 10
                            width: 24
                            height: 24
                            sourceSize.width: 24
                            sourceSize.height: 24
                            smooth: true
                            source: root.icon(cell.modelData)
                        }

                        Text {
                            id: where

                            anchors.right: parent.right
                            anchors.verticalCenter: badge.verticalCenter
                            anchors.rightMargin: 10
                            text: cell.modelData.scratchpad ? "scratch" : cell.modelData.workspace
                            color: Theme.popupSubtext
                            font.family: Appearance.fontFamily
                            font.pixelSize: Appearance.smallFontSize
                        }

                        Text {
                            anchors.left: badge.right
                            anchors.right: where.left
                            anchors.verticalCenter: badge.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            text: cell.modelData.title
                            color: Theme.popupText
                            elide: Text.ElideRight
                            font.family: Appearance.fontFamily
                            font.pixelSize: Appearance.smallFontSize
                        }

                        MouseArea {
                            anchors.fill: parent

                            // No hover selection: selecting recentres the strip, so
                            // the hovered cell would slide out from under the pointer
                            // and hand it the next one, which would do it again.
                            onClicked: {
                                WindowService.select(cell.index);
                                WindowService.commitCycle();
                            }
                        }
                    }
                }
            }
        }
    }
}
