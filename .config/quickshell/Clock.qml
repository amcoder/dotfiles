import QtQuick
import Quickshell

Text {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "ddd, MMM dd HH:mm")
    color: Theme.barStatusline
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
}
