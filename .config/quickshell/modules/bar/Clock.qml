import QtQuick
import Quickshell
import qs.config

Text {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "ddd, MMM dd HH:mm")
    color: Theme.barStatusline
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
}
