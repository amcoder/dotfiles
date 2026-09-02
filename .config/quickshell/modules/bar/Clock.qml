import QtQuick
import Quickshell
import qs.config
import qs.modules.calendar

MouseArea {
    id: root

    implicitWidth: label.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: calendar.toggle()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "ddd, MMM dd HH:mm")
        color: Theme.barStatusline
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    CalendarPopup {
        id: calendar

        anchorItem: root
        now: clock.date
    }
}
