import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.widgets

// One notification, drawn the same way in the popup stack and in the centre.
Rectangle {
    id: root

    required property var entry

    property bool showTime: false
    property int padding: 14
    property int imageSize: 48
    property int bodyLines: 6

    // Live while the notification exists, so replacing one by id redraws in place.
    readonly property var live: root.entry.notification
    readonly property var values: root.live ?? NotificationService.fields(root.entry)

    readonly property bool critical: root.values.urgency === NotificationUrgency.Critical
    readonly property bool hovered: hover.hovered
    readonly property int progress: {
        if (!root.live)
            return root.entry.progress ?? -1;
        return root.live.hints.value === undefined ? -1 : Math.round(root.live.hints.value);
    }

    readonly property string imageSource: {
        if (root.values.image)
            return root.values.image;
        if (root.values.appIcon)
            return `image://icon/${root.values.appIcon}`;
        return "";
    }

    // Actions other than "default", which is what clicking the body invokes.
    readonly property var buttons: {
        if (!root.live)
            return [];
        return root.live.actions.filter(action => action.identifier !== "default");
    }

    function age(): string {
        const seconds = Math.max(0, Math.round((NotificationService.now - root.entry.time) / 1000));

        if (seconds < 60)
            return "now";
        if (seconds < 3600)
            return `${Math.floor(seconds / 60)}m`;
        if (seconds < 86400)
            return `${Math.floor(seconds / 3600)}h`;
        return `${Math.floor(seconds / 86400)}d`;
    }

    signal dismissed

    implicitHeight: body.implicitHeight + root.padding * 2
    radius: 10
    color: Theme.popupBackground
    border.color: root.critical ? Theme.red : Theme.popupBorder
    border.width: 1

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: click => {
            if (click.button === Qt.RightButton)
                root.dismissed();
            else
                NotificationService.activate(root.entry);
        }
    }

    Image {
        id: image

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: root.padding
        visible: root.imageSource !== ""
        width: root.imageSize
        height: root.imageSize
        fillMode: Image.PreserveAspectFit
        sourceSize.width: root.imageSize
        sourceSize.height: root.imageSize
        source: root.imageSource
    }

    Column {
        id: body

        anchors.left: image.visible ? image.right : parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        anchors.leftMargin: image.visible ? 12 : root.padding
        spacing: 4

        Item {
            width: parent.width
            height: header.implicitHeight

            Row {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8

                Text {
                    id: summary

                    width: parent.width - meta.implicitWidth - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.values.summary
                    color: root.critical ? Theme.red : Theme.popupText
                    elide: Text.ElideRight
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.fontSize
                    font.bold: true
                }

                Row {
                    id: meta

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.values.appName !== ""
                        text: root.values.appName
                        color: Theme.popupSubtext
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showTime
                        text: root.age()
                        color: Theme.popupSubtext
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.smallFontSize + 4
                        height: width

                        Icon {
                            anchors.fill: parent
                            visible: root.hovered
                            name: "x"
                            size: parent.width
                            color: closeHover.hovered ? Theme.red : Theme.popupSubtext
                        }

                        HoverHandler {
                            id: closeHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.dismissed()
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: root.values.body !== ""
            text: root.values.body
            color: Theme.popupSubtext
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: root.bodyLines
            elide: Text.ElideRight
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.smallFontSize
        }

        LevelBar {
            width: parent.width
            visible: root.progress >= 0
            value: root.progress / 100
        }

        Row {
            visible: root.buttons.length > 0
            spacing: 8
            topPadding: 4

            Repeater {
                model: root.buttons

                Button {
                    required property var modelData

                    text: modelData.text

                    onActivated: NotificationService.invoke(root.entry, modelData)
                }
            }
        }
    }
}
