import QtQuick
import qs.config
import qs.modules.backup
import qs.services
import qs.widgets

// The backup indicator: a clock running backwards, which fills in the accent
// while a backup runs, turns red when the last one failed, and yellow when
// nothing has succeeded for two days. Clicking opens the backup panel.
//
// The colour binding is what warms BackupService, whose IpcHandler would
// otherwise never register.
MouseArea {
    id: root

    implicitWidth: icon.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: panel.toggle()

    Icon {
        id: icon

        anchors.centerIn: parent
        name: "clock-counter-clockwise"
        color: {
            if (BackupService.running)
                return Theme.blue;
            if (BackupService.failed)
                return Theme.red;
            if (BackupService.stale)
                return Theme.yellow;
            return Theme.barStatusline;
        }

        // The same "live" cue the recording indicator uses, so a backup in
        // progress reads as activity rather than as a colour.
        SequentialAnimation on opacity {
            running: BackupService.running
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

    BackupPanel {
        id: panel

        anchorItem: root
    }
}
