import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Wayland

Scope {
    id: root

    readonly property var focusedScreen: {
        const workspace = I3.workspaces.values.find(ws => ws.focused);
        const name = workspace && workspace.monitor ? workspace.monitor.name : "";

        for (const screen of Quickshell.screens) {
            if (screen.name === name)
                return screen;
        }

        return null;
    }

    // Highlighting a row repaints the running bar in that palette. Only
    // quickshell previews; everything else changes when the choice is committed.
    function preview(index: int): void {
        const theme = ThemeService.themes[index];
        Theme.preview = theme ? theme.colors : null;
    }

    function commit(index: int): void {
        const theme = ThemeService.themes[index];
        if (theme)
            ThemeService.commit(theme.name);
    }

    PanelWindow {
        id: window

        readonly property int padding: 16
        readonly property int rowHeight: 46
        readonly property int maxRows: 8

        visible: ThemeService.active
        screen: root.focusedScreen
        color: "transparent"

        anchors.top: true
        anchors.left: true
        anchors.right: true
        anchors.bottom: true
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-theme-picker"

        onVisibleChanged: {
            if (!window.visible)
                return;

            const index = ThemeService.themes.findIndex(theme => theme.name === ThemeService.current);
            list.currentIndex = index < 0 ? 0 : index;
            list.forceActiveFocus();
            root.preview(list.currentIndex);
        }

        MouseArea {
            anchors.fill: parent

            onClicked: ThemeService.hide()
        }

        Rectangle {
            id: dialog

            anchors.centerIn: parent
            width: 460
            implicitHeight: body.implicitHeight + window.padding * 2
            color: Theme.popupBackground
            border.color: Theme.popupBorder
            border.width: 1
            radius: 6

            Column {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: window.padding
                spacing: 12

                Row {
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "palette"
                        color: Theme.blue
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Theme"
                        color: Theme.popupText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.headingFontSize
                    }
                }

                ListView {
                    id: list

                    width: parent.width
                    height: Math.min(ThemeService.themes.length, window.maxRows) * window.rowHeight
                    clip: true
                    focus: true

                    model: ThemeService.themes

                    onCurrentIndexChanged: {
                        if (window.visible)
                            root.preview(list.currentIndex);
                    }

                    Keys.onEscapePressed: ThemeService.hide()
                    Keys.onReturnPressed: root.commit(list.currentIndex)
                    Keys.onEnterPressed: root.commit(list.currentIndex)

                    delegate: MouseArea {
                        id: row

                        required property int index
                        required property var modelData

                        width: list.width
                        height: window.rowHeight
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: list.currentIndex = row.index
                        onClicked: root.commit(row.index)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 4
                            color: list.currentIndex === row.index ? Theme.popupSelection : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                spacing: 5

                                Repeater {
                                    model: row.modelData.swatch

                                    Rectangle {
                                        required property var modelData

                                        width: 16
                                        height: 16
                                        radius: 3
                                        color: modelData
                                    }
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 130
                                text: row.modelData.label
                                color: Theme.popupText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }

                            Icon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 12
                                visible: row.modelData.name === ThemeService.current
                                name: "check"
                                color: Theme.green
                            }
                        }
                    }
                }
            }
        }
    }
}
