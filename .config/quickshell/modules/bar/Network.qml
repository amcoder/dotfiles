import QtQuick
import qs.config
import qs.modules.network
import qs.services
import qs.widgets

MouseArea {
    id: root

    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: panel.toggle()

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: NetworkService.icon
            color: {
                if (NetworkService.portal)
                    return Theme.yellow;
                if (!NetworkService.online)
                    return Theme.overlay1;
                return Theme.barStatusline;
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: NetworkService.activeVpns.length > 0
            size: Appearance.smallFontSize + 2
            name: "shield-check"
            color: Theme.green
        }
    }

    NetworkPanel {
        id: panel

        anchorItem: root
    }
}
