import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// What the bar's coffee cup is indicating: one section per mechanism, naming
// the windows and the processes that are holding the session awake.
BarPopup {
    id: root

    cardWidth: 340

    component Section: Column {
        id: section

        required property string icon
        required property string title
        required property var entries

        width: parent.width
        spacing: 4

        Row {
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                size: Appearance.smallFontSize + 2
                name: section.icon
                color: Theme.yellow
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: section.title
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }

        Repeater {
            model: section.entries

            Text {
                required property string modelData

                width: section.width
                leftPadding: Appearance.smallFontSize + 10
                text: modelData
                color: Theme.popupText
                elide: Text.ElideRight
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }
    }

    Text {
        text: "Idle inhibited"
        color: Theme.popupText
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    Section {
        visible: IdleInhibitService.windowInhibitors.length > 0
        icon: "app-window"
        title: "Windows"
        entries: IdleInhibitService.windowInhibitors
    }

    Section {
        visible: IdleInhibitService.systemInhibitors.length > 0
        icon: "terminal-window"
        title: "System"
        entries: IdleInhibitService.systemInhibitors
    }
}
