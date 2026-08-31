import QtQuick
import Quickshell.Io

MouseArea {
    id: root

    readonly property int refreshInterval: 60000

    property int count: 0

    visible: root.count > 0
    implicitWidth: label.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: check.running = true

    Process {
        id: check

        running: true
        command: ["messages", "-s"]

        stdout: StdioCollector {
            onStreamFinished: root.count = parseInt(this.text) || 0
        }
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: true

        onTriggered: check.running = true
    }

    Icon {
        id: label

        anchors.centerIn: parent
        name: "envelope"
        color: Theme.barStatusline
    }
}
