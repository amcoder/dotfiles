import QtQuick
import Quickshell.Io

MouseArea {
    id: root

    readonly property int refreshInterval: 3600000

    property int count: 0

    visible: root.count > 0
    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: check.running = true

    Process {
        id: check

        running: true
        command: ["sh", "-c", "apt-get -sq upgrade | grep -E '^[0-9]+ upgraded' | cut -d' ' -f1"]

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

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "package"
            color: Theme.barStatusline
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            color: Theme.barStatusline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
