import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// What the bar's capture indicators are indicating: one section per device,
// naming the processes that hold it. The pid is there to be acted on -- it is
// what turns "something is listening" into something answerable.
BarPopup {
    id: root

    cardWidth: 320

    component Section: Column {
        id: section

        required property string icon
        required property string title
        required property var users

        width: parent.width
        spacing: 4

        Row {
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                size: Appearance.smallFontSize + 2
                name: section.icon
                color: Theme.red
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
            model: section.users

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
        text: "In use"
        color: Theme.popupText
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.fontSize
    }

    Section {
        visible: PrivacyService.cameraActive
        icon: "video-camera"
        title: "Camera"
        users: PrivacyService.cameraUsers
    }

    Section {
        visible: PrivacyService.micActive
        icon: "microphone"
        title: "Microphone"
        users: PrivacyService.micUsers
    }
}
