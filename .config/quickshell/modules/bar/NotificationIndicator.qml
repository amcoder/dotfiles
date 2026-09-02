import QtQuick
import qs.config
import qs.modules.notifications
import qs.services
import qs.widgets

MouseArea {
    id: root

    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: click => {
        if (click.button === Qt.RightButton)
            NotificationService.toggleDnd();
        else
            NotificationService.toggleCentre();
    }

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: NotificationService.dnd ? "bell-slash" : "bell"
            color: NotificationService.dnd ? Theme.yellow : Theme.barStatusline
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: NotificationService.unread > 0
            text: NotificationService.unread
            color: NotificationService.dnd ? Theme.yellow : Theme.barStatusline
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    NotificationCentre {
        anchorItem: root
    }

    NotificationPopups {
        anchorItem: root
    }
}
