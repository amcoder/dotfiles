import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.windows

Scope {
    id: root

    readonly property int rowHeight: 52

    function icon(window: var): string {
        const entry = DesktopEntries.heuristicLookup(window.appId);
        const name = entry ? entry.icon : window.appId;
        return Quickshell.iconPath(name, "preferences-system-windows");
    }

    function place(window: var): string {
        return window.scratchpad ? "scratchpad" : `workspace ${window.workspace}`;
    }

    ModalOverlay {
        namespaceSuffix: "window-switcher"

        visible: WindowService.active
        closeOnClickOutside: true
        cardWidth: 720
        focusItem: list

        onDismissed: WindowService.hide()

        // The list is in MRU order, so the focused window is always first and
        // switching to it would be a no-op. Start on the one below it, which is
        // what makes a single press an alt-tab.
        onOpened: {
            list.reset();
            list.select(WindowService.windows.length > 1 ? 1 : 0);
        }

        Row {
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "app-window"
                color: Theme.blue
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Windows"
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
            }
        }

        FilterList {
            id: list

            width: parent.width
            placeholder: "Search windows"
            rowHeight: root.rowHeight
            maxRows: 9

            source: WindowService.windows
            fields: window => [window.title, window.appId, root.place(window)]

            onAccepted: window => WindowService.focusWindow(window)
            onSecondary: window => WindowService.closeWindow(window)
            onCancelled: WindowService.hide()

            delegate: ListRow {
                id: row

                required property int index
                required property var modelData

                width: list.width
                height: root.rowHeight
                margins: 2
                selected: row.ListView.isCurrentItem

                onEntered: row.ListView.view.currentIndex = row.index
                onActivated: WindowService.focusWindow(row.modelData)

                Image {
                    id: appIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    width: Appearance.launcherIconSize
                    height: Appearance.launcherIconSize
                    sourceSize.width: Appearance.launcherIconSize
                    sourceSize.height: Appearance.launcherIconSize
                    smooth: true
                    source: root.icon(row.modelData)
                }

                Text {
                    id: place

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 14
                    text: root.place(row.modelData)
                    color: Theme.popupSubtext
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }

                Column {
                    anchors.left: appIcon.right
                    anchors.right: place.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.modelData.title
                        color: Theme.popupText
                        elide: Text.ElideRight
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.appId
                        color: Theme.popupSubtext
                        elide: Text.ElideRight
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }
                }
            }
        }
    }
}
