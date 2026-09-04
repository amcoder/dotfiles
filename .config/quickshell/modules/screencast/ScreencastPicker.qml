import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The picker xdg-desktop-portal-wlr opens when something asks to screenshare.
//
// A grid rather than the shell's usual filtered list: what is being shared is a
// picture, and the whole point of choosing a single window over the whole
// screen is seeing which window you are about to hand over. Thumbnails are
// captured by `screencast-chooser` before the picker is asked to open, so this
// only ever draws files that already exist.
Scope {
    id: root

    readonly property int columns: 4
    readonly property int cellWidth: 282
    readonly property int cellHeight: 218

    // Scores after the first are scaled down, so a hit in a window's title
    // beats one in its workspace or its app id. Same falloff as FilterList.
    readonly property real fieldFalloff: 0.55

    function icon(target: var): string {
        const entry = DesktopEntries.heuristicLookup(target.appId ?? "");
        const name = entry ? entry.icon : (target.appId ?? "");
        return Quickshell.iconPath(name, "preferences-system-windows");
    }

    function place(target: var): string {
        if (target.kind === "screen")
            return "Entire screen";

        const workspace = target.workspace ?? -1;
        return workspace >= 0 ? `Workspace ${workspace}` : "Window";
    }

    ModalOverlay {
        id: overlay

        readonly property var results: {
            const query = field.text.trim();
            const scored = [];

            for (let i = 0; i < ScreencastService.targets.length; i++) {
                const target = ScreencastService.targets[i];
                const texts = [target.title, root.place(target), target.appId ?? ""];
                let best = 0;
                let matched = false;

                for (let f = 0; f < texts.length; f++) {
                    const raw = Fuzzy.score(query, texts[f] ?? "");
                    if (raw < 0)
                        continue;

                    const score = raw * Math.pow(root.fieldFalloff, f);
                    if (!matched || score > best) {
                        best = score;
                        matched = true;
                    }
                }

                if (matched)
                    scored.push({ target, score: best, order: i });
            }

            // With an empty query every score is 0, so the chooser's own order
            // -- screens first, then windows by workspace -- is what shows.
            scored.sort((a, b) => b.score - a.score || a.order - b.order);
            return scored.map(entry => entry.target);
        }

        // Deep enough to be worth scrolling only on a short screen.
        readonly property int visibleRows: {
            const height = overlay.screen ? overlay.screen.height : 1080;
            return Math.max(1, Math.min(3, Math.floor(height * 0.5 / root.cellHeight)));
        }

        function select(index: int): void {
            if (overlay.results.length === 0)
                return;

            // Clamped rather than wrapped: in a grid, falling off the bottom
            // row onto the top one reads as the selection jumping at random.
            grid.currentIndex = Math.max(0, Math.min(index, overlay.results.length - 1));
            grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
        }

        function activate(): void {
            const target = overlay.results[grid.currentIndex];
            if (target)
                ScreencastService.choose(target);
        }

        namespaceSuffix: "screencast-picker"

        visible: ScreencastService.active
        closeOnClickOutside: true
        cardWidth: root.columns * root.cellWidth + 32
        focusItem: field

        onDismissed: ScreencastService.cancel()

        onOpened: {
            field.text = "";
            grid.currentIndex = 0;
        }

        Item {
            width: parent.width
            implicitHeight: heading.implicitHeight

            Row {
                id: heading

                anchors.left: parent.left
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "video"
                    color: Theme.red
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Share your screen"
                    color: Theme.popupText
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.headingFontSize
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: heading.verticalCenter
                text: "Enter to share · Esc to cancel"
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }

        Item {
            id: nav

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Left:
                    overlay.select(grid.currentIndex - 1);
                    break;
                case Qt.Key_Right:
                    overlay.select(grid.currentIndex + 1);
                    break;
                case Qt.Key_Up:
                    overlay.select(grid.currentIndex - root.columns);
                    break;
                case Qt.Key_Down:
                    overlay.select(grid.currentIndex + root.columns);
                    break;
                case Qt.Key_Home:
                    overlay.select(0);
                    break;
                case Qt.Key_End:
                    overlay.select(overlay.results.length - 1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    overlay.activate();
                    break;
                case Qt.Key_Escape:
                    ScreencastService.cancel();
                    break;
                default:
                    return;
                }

                event.accepted = true;
            }
        }

        TextField {
            id: field

            width: parent.width
            placeholder: "Search windows and screens"
            keyHandlers: [nav]

            onTextChanged: grid.currentIndex = 0
            onAccepted: overlay.activate()
        }

        GridView {
            id: grid

            width: parent.width
            height: Math.min(Math.ceil(overlay.results.length / root.columns), overlay.visibleRows) * root.cellHeight
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0

            model: overlay.results

            delegate: Item {
                id: cell

                required property int index
                required property var modelData

                readonly property bool current: cell.GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight

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
                        anchors.margins: 6
                        height: Math.round(width * 9 / 16)
                        radius: 4
                        color: Theme.crust
                        clip: true

                        // Fitted rather than cropped: a window's real shape is
                        // part of what the answer to "what am I sharing?" is.
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: source !== ""
                            source: cell.modelData.thumbnail ? `file://${cell.modelData.thumbnail}` : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            sourceSize.width: 640
                        }

                        // grim refuses some clients' buffers outright, so a
                        // missing capture is expected rather than exceptional.
                        Image {
                            anchors.centerIn: parent
                            visible: !cell.modelData.thumbnail
                            width: 44
                            height: 44
                            sourceSize.width: 44
                            sourceSize.height: 44
                            smooth: true
                            source: root.icon(cell.modelData)
                        }
                    }

                    Item {
                        id: badge

                        anchors.left: parent.left
                        anchors.top: shot.bottom
                        anchors.leftMargin: 8
                        anchors.topMargin: 8
                        width: 22
                        height: 22

                        Image {
                            anchors.fill: parent
                            visible: cell.modelData.kind === "window"
                            sourceSize.width: 22
                            sourceSize.height: 22
                            smooth: true
                            source: root.icon(cell.modelData)
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: cell.modelData.kind === "screen"
                            name: "monitor"
                            size: 22
                            color: Theme.blue
                        }
                    }

                    Column {
                        anchors.left: badge.right
                        anchors.right: parent.right
                        anchors.top: badge.top
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 1

                        Text {
                            width: parent.width
                            text: cell.modelData.title
                            color: Theme.popupText
                            elide: Text.ElideRight
                            font.family: Appearance.fontFamily
                            font.pixelSize: Appearance.smallFontSize
                        }

                        Text {
                            width: parent.width
                            text: root.place(cell.modelData)
                            color: Theme.popupSubtext
                            elide: Text.ElideRight
                            font.family: Appearance.fontFamily
                            font.pixelSize: Appearance.smallFontSize
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: grid.currentIndex = cell.index
                        onClicked: ScreencastService.choose(cell.modelData)
                    }
                }
            }
        }

        Text {
            visible: overlay.results.length === 0
            text: "No matches"
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }
}
