import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The panel behind the bar's speaker icon, replacing pasystray: a level row
// per default device, the device lists, per-app stream volumes, and
// pavucontrol as the escape hatch for everything else (routing, profiles,
// per-app device moves).
BarPopup {
    id: root

    implicitWidth: 380

    component Heading: Text {
        color: Theme.popupSubtext
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize
    }

    // Mute toggle, slider and percentage for one node.
    component LevelRow: Item {
        id: level

        required property var node
        required property string onIcon
        required property string offIcon

        readonly property bool off: level.node?.audio?.muted ?? false
        readonly property real value: level.node?.audio?.volume ?? 0

        implicitHeight: 30

        MouseArea {
            id: toggle

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Appearance.iconSize
            implicitHeight: Appearance.iconSize
            cursorShape: Qt.PointingHandCursor

            onClicked: AudioService.toggleNodeMute(level.node)

            Icon {
                anchors.fill: parent
                name: level.off ? level.offIcon : level.onIcon
                color: level.off ? Theme.popupSubtext : Theme.popupText
            }
        }

        Slider {
            anchors.left: toggle.right
            anchors.right: percent.left
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            value: level.off ? 0 : level.value
            fillColor: level.off ? Theme.popupSubtext : Theme.blue

            onMoved: value => AudioService.setVolume(level.node, value)
        }

        Text {
            id: percent

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(level.value * 100)}%`
            color: Theme.popupSubtext
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    // One selectable device in an output or input list.
    component DeviceRow: ListRow {
        id: device

        required property var node
        required property bool active

        height: 26
        selected: device.active

        Icon {
            id: tick

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: device.active
            size: Appearance.smallFontSize
            name: "check"
            color: Theme.popupText
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6 + tick.width + 8
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: AudioService.label(device.node)
            color: device.active ? Theme.popupText : Theme.popupSubtext
            elide: Text.ElideRight
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }
    }

    Item {
        width: parent.width
        implicitHeight: title.implicitHeight

        Text {
            id: title

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Audio"
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }

        Text {
            id: advanced

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
                    root.visible = false;
                    AudioService.advanced();
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 4

        Heading {
            text: "Output"
        }

        LevelRow {
            width: parent.width
            node: AudioService.sink
            onIcon: AudioService.volume <= 0.5 ? "speaker-low" : "speaker-high"
            offIcon: "speaker-slash"
        }

        Repeater {
            model: AudioService.sinks

            DeviceRow {
                required property var modelData

                width: parent.width
                node: modelData
                active: AudioService.sink?.id === modelData.id

                onActivated: AudioService.setDefaultSink(modelData)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 4

        Heading {
            text: "Input"
        }

        LevelRow {
            width: parent.width
            node: AudioService.source
            onIcon: "microphone"
            offIcon: "microphone-slash"
        }

        Repeater {
            model: AudioService.sources

            DeviceRow {
                required property var modelData

                width: parent.width
                node: modelData
                active: AudioService.source?.id === modelData.id

                onActivated: AudioService.setDefaultSource(modelData)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 4
        visible: AudioService.streams.length > 0

        Heading {
            text: "Playing"
        }

        Repeater {
            model: AudioService.streams

            Column {
                id: stream

                required property var modelData

                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: AudioService.streamLabel(stream.modelData)
                    color: Theme.popupText
                    elide: Text.ElideRight
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }

                LevelRow {
                    width: parent.width
                    node: stream.modelData
                    onIcon: "speaker-high"
                    offIcon: "speaker-slash"
                }
            }
        }
    }
}
