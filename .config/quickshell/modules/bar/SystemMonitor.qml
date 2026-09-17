import QtQuick
import qs.config
import qs.modules.sysmon
import qs.services
import qs.widgets

// CPU and memory use as two gauge icons, filling from the bottom as the
// machine gets busier. One item rather than two: they open the same panel,
// which is the whole of what clicking either does.
//
// The bindings here are also what warm SystemMonitorService, which nothing
// else references while the panel is closed.
MouseArea {
    id: root

    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: panel.toggle()

    function levelColor(value: real): color {
        if (value >= 0.9)
            return Theme.red;
        if (value >= 0.7)
            return Theme.yellow;
        return Theme.barStatusline;
    }

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        GaugeIcon {
            name: "cpu"
            value: SystemMonitorService.cpu
            color: root.levelColor(value)
            glyphTop: 16 / 256
            glyphBottom: 240 / 256
        }

        GaugeIcon {
            name: "memory"
            value: SystemMonitorService.memoryFraction
            color: root.levelColor(value)
            glyphTop: 56 / 256
            glyphBottom: 208 / 256
        }
    }

    SystemMonitorPanel {
        id: panel

        anchorItem: root
    }
}
