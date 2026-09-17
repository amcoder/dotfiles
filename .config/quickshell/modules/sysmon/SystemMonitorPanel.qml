import QtQuick
import Quickshell.I3
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The panel behind the bar's CPU and memory gauges: a minute of CPU, memory
// and network history, every core, swap, load and uptime, and the processes
// using the most of it. gnome-system-monitor is the escape hatch for anything
// more, per-process control above all.
BarPopup {
    id: root

    readonly property int processRows: 8
    readonly property int processRowHeight: 22
    readonly property int coreColumns: 8

    property string sortKey: "cpu"

    readonly property var processes: SystemMonitorService.processes.slice().sort((a, b) => b[root.sortKey] - a[root.sortKey]).slice(0, root.processRows)

    cardWidth: 440

    // The process scan is the one costly read, so the watcher only does it
    // while this is open.
    onExpandedChanged: SystemMonitorService.detail = root.expanded

    component Heading: Item {
        id: heading

        required property string title
        property string detail: ""

        width: parent.width
        implicitHeight: headingTitle.implicitHeight

        Text {
            id: headingTitle

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: heading.title
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: heading.detail
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    // A labelled fill bar with its percentage, for memory and swap.
    component MeterRow: Item {
        id: meter

        required property string label
        required property real value
        property color fillColor: Theme.blue

        width: parent.width
        implicitHeight: 20

        Text {
            id: meterLabel

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 60
            text: meter.label
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        LevelBar {
            anchors.left: meterLabel.right
            anchors.right: meterPercent.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            value: meter.value
            fillColor: meter.fillColor
        }

        Text {
            id: meterPercent

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(meter.value * 100)}%`
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    // One of the two column headers that also picks the sort order.
    component SortHeader: Text {
        id: header

        required property string key

        readonly property bool active: root.sortKey === header.key

        horizontalAlignment: Text.AlignRight
        color: header.active || sortMouse.containsMouse ? Theme.popupText : Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize
        font.underline: header.active

        MouseArea {
            id: sortMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.sortKey = header.key
        }
    }

    Item {
        width: parent.width
        implicitHeight: title.implicitHeight

        Text {
            id: title

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "System"
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "advanced…"
            color: advancedMouse.containsMouse ? Theme.popupText : Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize

            MouseArea {
                id: advancedMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.expanded = false;
                    I3.dispatch("exec gnome-system-monitor");
                }
            }
        }
    }

    Item {
        width: parent.width
        implicitHeight: uptime.implicitHeight

        Text {
            id: uptime

            anchors.left: parent.left
            text: `up ${SystemMonitorService.formatUptime(SystemMonitorService.uptime)}`
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        Text {
            anchors.right: parent.right
            text: `load ${SystemMonitorService.load.map(l => l.toFixed(2)).join("  ")}`
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    Column {
        width: parent.width
        spacing: 6

        Heading {
            title: "CPU"
            detail: `${Math.round(SystemMonitorService.cpu * 100)}%`
        }

        HistoryGraph {
            width: parent.width
            series: [SystemMonitorService.cpuHistory]
            colors: [Theme.blue]
            capacity: SystemMonitorService.historyLength
            max: 1
        }

        Grid {
            id: cores

            width: parent.width
            columns: root.coreColumns
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: SystemMonitorService.cores

                LevelBar {
                    required property real modelData

                    width: (cores.width - cores.columnSpacing * (cores.columns - 1)) / cores.columns
                    implicitHeight: 6
                    value: modelData
                    fillColor: Theme.blue
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 6

        Heading {
            title: "Memory"
            detail: `${SystemMonitorService.formatBytes(SystemMonitorService.memory.used)} / ${SystemMonitorService.formatBytes(SystemMonitorService.memory.total)}`
        }

        HistoryGraph {
            width: parent.width
            series: [SystemMonitorService.memoryHistory]
            colors: [Theme.green]
            capacity: SystemMonitorService.historyLength
            max: 1
        }

        MeterRow {
            label: "Memory"
            value: SystemMonitorService.memoryFraction
            fillColor: Theme.green
        }

        MeterRow {
            visible: SystemMonitorService.swap.total > 0
            label: "Swap"
            value: SystemMonitorService.swapFraction
            fillColor: Theme.peach
        }
    }

    Column {
        width: parent.width
        spacing: 6

        Heading {
            title: "Network"
            detail: `↓ ${SystemMonitorService.formatRate(SystemMonitorService.net.rx)}   ↑ ${SystemMonitorService.formatRate(SystemMonitorService.net.tx)}`
        }

        HistoryGraph {
            width: parent.width
            series: [SystemMonitorService.netHistory.map(s => s.rx), SystemMonitorService.netHistory.map(s => s.tx)]
            colors: [Theme.teal, Theme.mauve]
            capacity: SystemMonitorService.historyLength
            max: 0
        }
    }

    Column {
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            implicitHeight: processesTitle.implicitHeight

            Text {
                id: processesTitle

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Processes"
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }

            SortHeader {
                anchors.right: memHeader.left
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                key: "cpu"
                text: "CPU"
            }

            SortHeader {
                id: memHeader

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 80
                key: "mem"
                text: "Memory"
            }
        }

        // Fixed at `processRows` tall, so the list filling in a moment after
        // the panel opens does not grow the card.
        Column {
            width: parent.width
            height: root.processRows * root.processRowHeight

            Repeater {
                model: root.processes

                Item {
                    id: process

                    required property var modelData

                    width: parent.width
                    height: root.processRowHeight

                    Text {
                        anchors.left: parent.left
                        anchors.right: processCpu.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${process.modelData.name}  (${process.modelData.pid})`
                        color: Theme.popupText
                        elide: Text.ElideRight
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }

                    Text {
                        id: processCpu

                        anchors.right: processMem.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 60
                        horizontalAlignment: Text.AlignRight
                        text: `${(process.modelData.cpu * 100).toFixed(1)}%`
                        color: Theme.popupSubtext
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }

                    Text {
                        id: processMem

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 80
                        horizontalAlignment: Text.AlignRight
                        text: SystemMonitorService.formatBytes(process.modelData.mem)
                        color: Theme.popupSubtext
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }
                }
            }
        }
    }
}
