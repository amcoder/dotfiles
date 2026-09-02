import QtQuick
import qs.config
import qs.modules.audio
import qs.services
import qs.widgets

MouseArea {
    id: root

    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: event => {
        if (event.button === Qt.MiddleButton)
            AudioService.toggleNodeMute(AudioService.sink);
        else
            panel.toggle();
    }

    // No OSD from here: the bar already shows the number the OSD would.
    onWheel: event => {
        const delta = event.angleDelta.y > 0 ? AudioService.step : -AudioService.step;
        AudioService.setMuted(AudioService.sink, false);
        AudioService.setVolume(AudioService.sink, AudioService.volume + delta);
    }

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: AudioService.icon
            color: AudioService.muted ? Theme.overlay1 : Theme.barStatusline
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Math.round(AudioService.volume * 100)}%`
            color: AudioService.muted ? Theme.overlay1 : Theme.barStatusline
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    AudioPanel {
        id: panel

        anchorItem: root
    }
}
