import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.windows

Scope {
    id: root

    readonly property int rowHeight: 46
    readonly property int maxRows: 8

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

    ModalOverlay {
        namespaceSuffix: "theme-picker"

        visible: ThemeService.active
        dim: false
        closeOnClickOutside: true
        cardWidth: 460
        focusItem: list

        onDismissed: ThemeService.hide()

        onOpened: {
            const index = ThemeService.themes.findIndex(theme => theme.name === ThemeService.current);
            list.currentIndex = index < 0 ? 0 : index;
            root.preview(list.currentIndex);
        }

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
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
            }
        }

        ListView {
            id: list

            width: parent.width
            height: Math.min(ThemeService.themes.length, root.maxRows) * root.rowHeight
            clip: true
            focus: true

            model: ThemeService.themes

            onCurrentIndexChanged: {
                if (ThemeService.active)
                    root.preview(list.currentIndex);
            }

            Keys.onReturnPressed: root.commit(list.currentIndex)
            Keys.onEnterPressed: root.commit(list.currentIndex)

            delegate: ListRow {
                id: row

                required property int index
                required property var modelData

                width: list.width
                height: root.rowHeight
                margins: 2
                selected: list.currentIndex === row.index

                onEntered: list.currentIndex = row.index
                onActivated: root.commit(row.index)

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
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.fontSize
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
