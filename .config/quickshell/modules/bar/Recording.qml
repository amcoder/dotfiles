import QtQuick
import qs.config
import qs.services
import qs.widgets

// The recording indicator, shown only while wf-recorder is running. Clicking
// it stops the recording, which is the same thing the keybind does.
//
// The binding on `visible` is also what warms RecordingService: it is
// otherwise reached only over IPC, and a singleton nobody references is never
// created, so its IpcHandler would never register.
MouseArea {
    id: root

    visible: RecordingService.active
    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: RecordingService.stop()

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        Icon {
            id: dot

            anchors.verticalCenter: parent.verticalCenter
            name: "record"
            color: Theme.red

            // The conventional "live" cue, and the point of the indicator: a
            // recording nobody remembers starting is the failure mode.
            SequentialAnimation on opacity {
                running: root.visible
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    to: 0.35
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    to: 1
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatted(RecordingService.elapsed)
            color: Theme.red
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    function formatted(seconds: int): string {
        const pad = n => String(n).padStart(2, "0");
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;

        if (m < 60)
            return `${m}:${pad(s)}`;

        return `${Math.floor(m / 60)}:${pad(m % 60)}:${pad(s)}`;
    }
}
