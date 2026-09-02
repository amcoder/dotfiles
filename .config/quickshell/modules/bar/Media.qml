import QtQuick
import qs.config
import qs.modules.media
import qs.services
import qs.widgets

// Now playing, in the left section rather than with the other status items:
// its width changes on every track, and the right section is anchored to the
// right edge, so putting it there would shift every icon along it each time a
// song ends.
MouseArea {
    id: root

    visible: MprisService.available
    implicitWidth: visible ? layout.implicitWidth : 0
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            MprisService.playPause();
        else
            panel.toggle();
    }

    // The icon reads as state rather than as the action a click would take --
    // clicking opens the panel -- so it is backed up by dimming the whole item
    // while paused, which a play/pause glyph alone leaves ambiguous.
    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6
        opacity: MprisService.playing ? 1 : 0.55

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: MprisService.playing ? "play" : "pause"
            color: Theme.barStatusline
            size: Appearance.fontSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 280)
            text: MprisService.label
            color: Theme.barStatusline
            elide: Text.ElideRight
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    MediaPanel {
        id: panel

        anchorItem: root
    }
}
