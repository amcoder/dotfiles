import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The panel behind the bar's now-playing item: art, track, a seek bar, the
// transport, and — only once there is more than one — the players to choose
// between.
BarPopup {
    id: root

    cardWidth: 400

    // MPRIS never signals position; Quickshell extrapolates it from the last
    // fetched value, so a poll is a local read rather than a bus round trip.
    // Paused playback does not move, so the timer only runs while it does.
    property real position: 0

    function sync(): void {
        root.position = MprisService.active?.position ?? 0;
    }

    function clock(seconds: real): string {
        if (!(seconds > 0))
            return "0:00";

        const total = Math.floor(seconds);
        const s = String(total % 60).padStart(2, "0");
        const m = Math.floor(total / 60) % 60;
        const h = Math.floor(total / 3600);

        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`;
    }

    onExpandedChanged: root.sync()

    Timer {
        interval: 1000
        repeat: true
        running: root.expanded && MprisService.playing
        onTriggered: root.sync()
    }

    Connections {
        target: MprisService

        function onActiveChanged(): void {
            root.sync();
        }

        function onPlayingChanged(): void {
            root.sync();
        }
    }

    component Transport: MouseArea {
        id: transport

        required property string icon

        signal activated

        implicitWidth: Appearance.iconSize + 16
        implicitHeight: Appearance.iconSize + 16
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: transport.enabled ? 1 : 0.4

        onClicked: transport.activated()

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: transport.containsMouse && transport.enabled ? Theme.popupHover : "transparent"
        }

        Icon {
            anchors.centerIn: parent
            name: transport.icon
            color: Theme.popupText
        }
    }

    // Art, with the track beside it. The square stands whether or not there is
    // artwork, so the row below it does not move when a track without any
    // follows one with.
    Item {
        width: parent.width
        implicitHeight: 76

        Rectangle {
            id: art

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 76
            height: 76
            color: Theme.surface0

            Icon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                name: "music-note"
                size: 32
                color: Theme.popupSubtext
            }

            Image {
                id: cover

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: MprisService.active?.trackArtUrl ?? ""
            }
        }

        Column {
            anchors.left: art.right
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: MprisService.title || MprisService.active?.identity || ""
                color: Theme.popupText
                elide: Text.ElideRight
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: MprisService.artist
                color: Theme.popupSubtext
                elide: Text.ElideRight
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: MprisService.active?.trackAlbum ?? ""
                color: Theme.popupSubtext
                elide: Text.ElideRight
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }
    }

    Item {
        width: parent.width
        visible: (MprisService.active?.lengthSupported ?? false) && (MprisService.active?.length ?? 0) > 0
        implicitHeight: visible ? seek.implicitHeight + elapsed.implicitHeight + 2 : 0

        Slider {
            id: seek

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            enabled: MprisService.active?.canSeek ?? false
            fillColor: Theme.blue
            value: {
                const length = MprisService.active?.length ?? 0;
                return length > 0 ? root.position / length : 0;
            }

            onMoved: fraction => {
                MprisService.seek(fraction);
                root.position = fraction * (MprisService.active?.length ?? 0);
            }
        }

        Text {
            id: elapsed

            anchors.left: parent.left
            anchors.top: seek.bottom
            anchors.topMargin: 2
            text: root.clock(root.position)
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Text {
            anchors.right: parent.right
            anchors.baseline: elapsed.baseline
            text: root.clock(MprisService.active?.length ?? 0)
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Transport {
            icon: "skip-back"
            enabled: MprisService.active?.canGoPrevious ?? false

            onActivated: MprisService.previous()
        }

        Transport {
            icon: MprisService.playing ? "pause" : "play"
            enabled: MprisService.active?.canTogglePlaying ?? false

            onActivated: MprisService.playPause()
        }

        Transport {
            icon: "skip-forward"
            enabled: MprisService.active?.canGoNext ?? false

            onActivated: MprisService.next()
        }
    }

    // Only worth drawing once there is a choice to make.
    Column {
        width: parent.width
        visible: MprisService.players.length > 1
        spacing: 4

        Text {
            text: "Players"
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Repeater {
            model: MprisService.players

            ListRow {
                id: playerRow

                required property var modelData

                width: parent.width
                height: 28
                selected: playerRow.modelData === MprisService.active

                onActivated: MprisService.select(playerRow.modelData)

                Icon {
                    id: state

                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    size: Appearance.smallFontSize + 2
                    name: playerRow.modelData.isPlaying ? "play" : "pause"
                    color: playerRow.selected ? Theme.popupText : Theme.popupSubtext
                }

                Text {
                    anchors.left: state.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: playerRow.modelData.identity
                    color: playerRow.selected ? Theme.popupText : Theme.popupSubtext
                    elide: Text.ElideRight
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }
            }
        }
    }
}
