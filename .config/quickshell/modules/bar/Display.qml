import QtQuick
import qs.config
import qs.modules.display
import qs.services
import qs.widgets

// The monitor icon, opening the display panel. The binding on the output
// count is also what warms DisplayService, which nothing else references
// while the panel is closed.
MouseArea {
    id: root

    implicitWidth: icon.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: panel.toggle()

    Icon {
        id: icon

        anchors.centerIn: parent
        name: "monitor"
        color: DisplayService.activeCount > 0 ? Theme.barStatusline : Theme.overlay1
    }

    DisplayPanel {
        id: panel

        anchorItem: root
    }
}
