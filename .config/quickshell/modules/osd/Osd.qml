import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.services
import qs.widgets

// The transient volume/brightness card, bottom centre so it never lands under
// the notification stack. `mask` is empty deliberately: an overlay layer
// surface swallows every pointer event in its geometry without one.
//
// The three descriptors below are unconditional bindings on purpose. A QML
// singleton is created when it is first referenced, and AudioService and
// BrightnessService are otherwise reached only over IPC -- so this, the one
// thing that draws them, is also what registers their handlers.
PanelWindow {
    id: root

    readonly property int padding: 16

    readonly property var volume: ({
            icon: AudioService.muted ? "speaker-slash" : AudioService.volume <= 0 ? "speaker-none" : AudioService.volume <= 0.5 ? "speaker-low" : "speaker-high",
            label: "Volume",
            value: AudioService.muted ? 0 : AudioService.volume,
            off: AudioService.muted
        })

    readonly property var microphone: ({
            icon: AudioService.micMuted ? "microphone-slash" : "microphone",
            label: "Microphone",
            value: -1,
            off: AudioService.micMuted
        })

    readonly property var brightness: ({
            icon: BrightnessService.fraction <= 0.5 ? "sun-dim" : "sun",
            label: "Brightness",
            value: BrightnessService.fraction,
            off: false
        })

    readonly property var content: {
        if (OsdService.source === "microphone")
            return root.microphone;
        if (OsdService.source === "brightness")
            return root.brightness;
        return root.volume;
    }

    screen: FocusedScreen.screen
    visible: OsdService.active
    color: "transparent"
    focusable: false

    anchors.bottom: true
    margins.bottom: 96

    implicitWidth: 320
    implicitHeight: column.implicitHeight + 2 * root.padding
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"

    mask: Region {}

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        border.width: 1
    }

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        spacing: 12

        Item {
            width: parent.width
            implicitHeight: Math.max(icon.implicitHeight, label.implicitHeight)

            Icon {
                id: icon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: root.content.icon
                color: root.content.off ? Theme.popupSubtext : Theme.popupText
            }

            Text {
                id: label

                anchors.left: icon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.content.label
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.content.value >= 0
                text: `${Math.round(root.content.value * 100)}%`
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
            }
        }

        LevelBar {
            width: parent.width
            visible: root.content.value >= 0
            value: root.content.value
            fillColor: root.content.off ? Theme.popupSubtext : Theme.blue
        }
    }
}
