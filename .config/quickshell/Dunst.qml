import QtQuick
import Quickshell.Io

MouseArea {
    id: root

    readonly property int refreshInterval: 5000

    property bool paused: false
    property int count: 0

    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => action.run(mouse.button === Qt.RightButton ? ["dunstctl", "history-pop"] : ["dunstctl", "set-paused", "toggle"])

    Process {
        id: check

        running: true
        command: ["sh", "-c", "dunstctl is-paused; dunstctl count waiting"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                root.paused = lines[0] === "true";
                root.count = parseInt(lines[1]) || 0;
            }
        }
    }

    Process {
        id: action

        function run(command) {
            action.command = command;
            action.running = true;
        }

        onExited: check.running = true
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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.paused ? "" : ""
            color: root.paused ? Theme.yellow : Theme.barStatusline
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.paused && root.count > 0
            text: root.count
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
