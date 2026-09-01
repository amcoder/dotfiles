import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.windows

Scope {
    id: root

    readonly property int rowHeight: 52

    // One row shape for both modes: an application (optionally one of its
    // desktop actions) or a bare executable name in run mode.
    //
    // Sorted by name, because FilterList only sorts by score and then weight:
    // with no query every score is 0, so the source order is what an untrained
    // frecency table falls back to.
    readonly property var items: {
        if (LauncherService.runMode)
            return LauncherService.executables.map(command => ({ entry: null, action: null, command }));

        const items = [];
        const entries = LauncherService.applications.slice().sort((a, b) => a.name.localeCompare(b.name));

        for (const entry of entries) {
            items.push({ entry, action: null, command: "" });

            // Desktop actions only appear once there is a query: with none they
            // would pad the frecency-ordered list with rows nobody asked for.
            // wofi hid them outright (no_actions=true).
            if (list.query.trim() === "")
                continue;

            for (const action of entry.actions)
                items.push({ entry, action, command: "" });
        }

        return items;
    }

    function label(item: var): string {
        if (item.entry === null)
            return item.command;

        return item.action === null ? item.entry.name : `${item.entry.name}: ${item.action.name}`;
    }

    function subtitle(item: var): string {
        if (item.entry === null)
            return "";

        return item.entry.genericName || item.entry.comment;
    }

    function icon(item: var): string {
        if (item.entry === null)
            return Quickshell.iconPath("application-x-executable");

        const name = item.action !== null && item.action.icon !== "" ? item.action.icon : item.entry.icon;
        return Quickshell.iconPath(name, "application-x-executable");
    }

    function fields(item: var): var {
        if (item.entry === null)
            return [item.command];

        if (item.action !== null)
            return [root.label(item), item.action.name];

        return [item.entry.name, item.entry.genericName, item.entry.comment, item.entry.keywords.join(" "), item.entry.categories.join(" ")];
    }

    function activate(item: var): void {
        if (item.entry === null)
            LauncherService.runCommand(item.command);
        else if (item.action === null)
            LauncherService.launch(item.entry);
        else
            LauncherService.launchAction(item.entry, item.action);
    }

    ModalOverlay {
        namespaceSuffix: "launcher"

        visible: LauncherService.active
        closeOnClickOutside: true
        cardWidth: 640
        focusItem: list

        onDismissed: LauncherService.hide()

        onOpened: list.reset()

        Row {
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: LauncherService.runMode ? "terminal-window" : "magnifying-glass"
                color: Theme.blue
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: LauncherService.runMode ? "Run" : "Applications"
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
            }
        }

        FilterList {
            id: list

            width: parent.width
            placeholder: LauncherService.runMode ? "Command" : "Search applications"
            rowHeight: root.rowHeight
            maxRows: 9
            fixedHeight: true

            source: root.items
            fields: item => root.fields(item)
            weight: item => item.entry === null ? 0 : LauncherService.frecency(item.entry.id) - (item.action === null ? 0 : 1)

            onAccepted: item => root.activate(item)
            onCancelled: LauncherService.hide()

            // Run mode accepts a command line with arguments, which matches no
            // row, so Return falls back to running the query verbatim.
            Keys.onPressed: event => {
                if (!LauncherService.runMode)
                    return;
                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                    return;
                if (list.query.trim() === "")
                    return;

                LauncherService.runCommand(list.query.trim());
                event.accepted = true;
            }

            delegate: ListRow {
                id: row

                required property int index
                required property var modelData

                width: list.width
                height: root.rowHeight
                margins: 2
                selected: row.ListView.isCurrentItem

                onEntered: row.ListView.view.currentIndex = row.index
                onActivated: root.activate(row.modelData)

                Image {
                    id: appIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: row.modelData.action === null ? 12 : 34
                    width: Appearance.launcherIconSize
                    height: Appearance.launcherIconSize
                    sourceSize.width: Appearance.launcherIconSize
                    sourceSize.height: Appearance.launcherIconSize
                    smooth: true
                    source: root.icon(row.modelData)
                }

                Column {
                    anchors.left: appIcon.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 1

                    Text {
                        width: parent.width
                        text: root.label(row.modelData)
                        color: Theme.popupText
                        elide: Text.ElideRight
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.subtitle(row.modelData)
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
