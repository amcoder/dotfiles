import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// A window over the snapshots on the NAS: the snapshots down the left, the
// directory the window is in on the right, and moving between snapshots keeps
// the directory -- so a file's history is read by walking the left column with
// the file in view, which is what Time Machine's timeline does. Each entry says
// whether it changed in that snapshot; entries the snapshot before had and this
// one lacks are listed as deleted, and can be opened and restored from there.
//
// This runs as its own quickshell process (backups.qml), not inside the bar.
FloatingWindow {
    id: window

    readonly property int rowHeight: 32
    readonly property int sidebarWidth: 280

    property int selectedIndex: -1
    readonly property var selected: window.selectedIndex >= 0 && window.selectedIndex < BackupArchiveService.visibleEntries.length ? BackupArchiveService.visibleEntries[window.selectedIndex] : null

    // The entry a restore is being confirmed for.
    property var confirming: null

    title: "Backups"
    minimumSize: Qt.size(960, 560)
    implicitWidth: 1280
    implicitHeight: 780
    color: Theme.base

    onVisibleChanged: {
        if (!window.visible)
            Qt.quit();
    }

    Component.onCompleted: BackupArchiveService.refreshSnapshots()

    // What `backup-browser` calls to bring an open window forward.
    IpcHandler {
        target: "browser"

        function raise(): void {
            I3.dispatch(`[app_id="quickshell" title="^${window.title}$"] focus`);
        }
    }

    Connections {
        target: BackupArchiveService

        function onSnapshotsChanged(): void {
            const snapshots = BackupArchiveService.snapshots;
            if (BackupArchiveService.snapshot === "" && snapshots.length > 0)
                BackupArchiveService.open(snapshots[0].name, "");
        }

        function onEntriesChanged(): void {
            window.selectedIndex = BackupArchiveService.visibleEntries.length > 0 ? 0 : -1;
        }

        function onOnlyChangedChanged(): void {
            window.selectedIndex = BackupArchiveService.visibleEntries.length > 0 ? 0 : -1;
        }
    }

    function activate(entry: var): void {
        if (entry === null)
            return;
        if (entry.kind === "dir" && entry.change !== "deleted")
            BackupArchiveService.enter(entry.name);
        else
            BackupArchiveService.openEntry(entry);
    }

    function stepSnapshot(delta: int): void {
        const snapshots = BackupArchiveService.snapshots;
        const index = snapshots.findIndex(s => s.name === BackupArchiveService.snapshot);
        const next = Math.max(0, Math.min(snapshots.length - 1, index + delta));
        if (next !== index)
            BackupArchiveService.open(snapshots[next].name, BackupArchiveService.path);
    }

    function askRestore(entry: var): void {
        if (entry === null || BackupArchiveService.restoring)
            return;
        window.confirming = entry;
    }

    function changeColor(change: var): color {
        switch (change) {
        case "new":
            return Theme.green;
        case "changed":
            return Theme.yellow;
        case "deleted":
            return Theme.red;
        default:
            return Theme.overlay0;
        }
    }

    function changeLabel(entry: var): string {
        switch (entry.change) {
        case "new":
            return "new";
        case "changed":
            return entry.kind === "dir" ? "listing changed" : "changed";
        case "deleted":
            return "deleted";
        default:
            return "";
        }
    }

    component Label: Text {
        color: Theme.text
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize
        elide: Text.ElideRight
    }

    component Link: Text {
        id: link

        signal activated

        color: linkMouse.containsMouse ? Theme.text : Theme.subtext0
        font.family: Appearance.fontFamily
        font.pixelSize: Appearance.smallFontSize

        MouseArea {
            id: linkMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: link.activated()
        }
    }

    component Toggle: MouseArea {
        id: toggle

        required property string text
        required property bool on

        implicitWidth: toggleRow.implicitWidth
        implicitHeight: 24
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Row {
            id: toggleRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 3
                color: toggle.on ? Theme.blue : "transparent"
                border.color: toggle.on ? Theme.blue : Theme.overlay0
                border.width: 1

                Icon {
                    anchors.centerIn: parent
                    visible: toggle.on
                    name: "check"
                    size: 14
                    color: Theme.base
                }
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: toggle.text
                color: toggle.containsMouse ? Theme.text : Theme.subtext0
            }
        }
    }

    component SnapshotRow: ListRow {
        id: snapshotRow

        required property var modelData
        required property int index

        readonly property bool isCurrent: snapshotRow.modelData.name === BackupArchiveService.snapshot

        width: ListView.view.width
        height: 48
        margins: 4
        selected: snapshotRow.isCurrent

        onActivated: BackupArchiveService.open(snapshotRow.modelData.name, BackupArchiveService.path)

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: tag.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                width: parent.width
                text: BackupArchiveService.formatSnapshotDay(snapshotRow.modelData.time)
                color: snapshotRow.isCurrent ? Theme.text : Theme.subtext1
                font.pixelSize: Appearance.fontSize - 3
            }

            Label {
                width: parent.width
                text: Qt.formatTime(new Date(snapshotRow.modelData.time * 1000), "HH:mm")
                color: Theme.subtext0
            }
        }

        Label {
            id: tag

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: snapshotRow.modelData.name
            color: Theme.overlay1
        }
    }

    component EntryRow: ListRow {
        id: entryRow

        required property var modelData
        required property int index

        readonly property bool deleted: entryRow.modelData.change === "deleted"

        width: ListView.view.width
        height: window.rowHeight
        selected: entryRow.index === window.selectedIndex
        acceptedButtons: Qt.LeftButton

        onPressed: window.selectedIndex = entryRow.index
        onDoubleClicked: window.activate(entryRow.modelData)

        opacity: entryRow.deleted ? 0.6 : 1

        Icon {
            id: kindIcon

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            size: 20
            name: {
                switch (entryRow.modelData.kind) {
                case "dir":
                    return "folder";
                case "link":
                    return "link-simple";
                default:
                    return "file";
                }
            }
            color: entryRow.modelData.kind === "dir" ? Theme.blue : Theme.subtext0
        }

        Label {
            anchors.left: kindIcon.right
            anchors.leftMargin: 10
            anchors.right: sizeLabel.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.modelData.name
            font.strikeout: entryRow.deleted
        }

        Label {
            id: sizeLabel

            anchors.right: dateLabel.left
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            horizontalAlignment: Text.AlignRight
            text: BackupArchiveService.formatSize(entryRow.modelData.size)
            color: Theme.subtext0
        }

        Label {
            id: dateLabel

            anchors.right: changeLabel.left
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            horizontalAlignment: Text.AlignRight
            text: BackupArchiveService.formatDate(entryRow.modelData.mtime)
            color: Theme.subtext0
        }

        Item {
            id: changeLabel

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 160
            height: parent.height

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                visible: entryRow.modelData.change !== null && entryRow.modelData.change !== "same"
                color: window.changeColor(entryRow.modelData.change)
            }

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: window.changeLabel(entryRow.modelData)
                color: window.changeColor(entryRow.modelData.change)
            }
        }
    }

    Item {
        id: content

        anchors.fill: parent
        focus: true

        Component.onCompleted: content.forceActiveFocus()

        Keys.onPressed: event => {
            if (window.confirming !== null) {
                if (event.key === Qt.Key_Escape) {
                    window.confirming = null;
                    event.accepted = true;
                }
                return;
            }

            const count = BackupArchiveService.visibleEntries.length;
            switch (event.key) {
            case Qt.Key_Down:
                if (event.modifiers & Qt.ControlModifier)
                    window.stepSnapshot(1);
                else if (count > 0)
                    window.selectedIndex = Math.min(count - 1, window.selectedIndex + 1);
                break;
            case Qt.Key_Up:
                if (event.modifiers & Qt.ControlModifier)
                    window.stepSnapshot(-1);
                else if (count > 0)
                    window.selectedIndex = Math.max(0, window.selectedIndex - 1);
                break;
            case Qt.Key_PageDown:
                window.stepSnapshot(1);
                break;
            case Qt.Key_PageUp:
                window.stepSnapshot(-1);
                break;
            case Qt.Key_Home:
                if (count > 0)
                    window.selectedIndex = 0;
                break;
            case Qt.Key_End:
                if (count > 0)
                    window.selectedIndex = count - 1;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                window.activate(window.selected);
                break;
            case Qt.Key_Backspace:
                BackupArchiveService.up();
                break;
            case Qt.Key_R:
                if (event.modifiers & Qt.ControlModifier)
                    window.askRestore(window.selected);
                else
                    return;
                break;
            case Qt.Key_Escape:
                window.visible = false;
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        // Snapshots.
        Rectangle {
            id: sidebar

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: window.sidebarWidth
            color: Theme.mantle

            Column {
                id: sidebarHeader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 4

                Row {
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "clock-counter-clockwise"
                        color: Theme.blue
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Snapshots"
                        color: Theme.text
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                    }
                }

                Label {
                    width: parent.width
                    text: {
                        if (BackupArchiveService.loadingSnapshots)
                            return "Reading the NAS…";
                        if (BackupArchiveService.snapshotsError !== "")
                            return BackupArchiveService.snapshotsError;
                        return `${BackupArchiveService.snapshots.length} on beedle`;
                    }
                    color: BackupArchiveService.snapshotsError !== "" ? Theme.red : Theme.subtext0
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
            }

            ListView {
                id: snapshotList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: sidebarHeader.bottom
                anchors.bottom: sidebarFooter.top
                anchors.topMargin: 12
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                clip: true
                model: BackupArchiveService.snapshots
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false

                delegate: SnapshotRow {}
            }

            Column {
                id: sidebarFooter

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                spacing: 4

                Label {
                    width: parent.width
                    text: BackupArchiveService.previous ? `Changes are against ${BackupArchiveService.previous.name}, ${BackupArchiveService.formatSnapshotDay(BackupArchiveService.previous.time).toLowerCase()} ${Qt.formatTime(new Date(BackupArchiveService.previous.time * 1000), "HH:mm")}.` : (BackupArchiveService.snapshot !== "" ? "The oldest snapshot: nothing to compare against." : "")
                    color: Theme.subtext0
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                Label {
                    width: parent.width
                    text: "Ctrl+↑/↓ or PageUp/PageDown move between snapshots."
                    color: Theme.overlay1
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                Link {
                    text: "refresh"

                    onActivated: {
                        BackupArchiveService.refreshSnapshots();
                        BackupArchiveService.reload();
                    }
                }
            }
        }

        // The directory.
        Item {
            id: main

            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Item {
                id: toolbar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                height: 32

                Button {
                    id: upButton

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 32
                    implicitWidth: 32
                    text: "↑"
                    enabled: BackupArchiveService.path !== ""

                    onActivated: BackupArchiveService.up()
                }

                // The path as clickable segments, Home first.
                Flow {
                    id: crumbs

                    anchors.left: upButton.right
                    anchors.right: filters.left
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        id: crumbRepeater

                        model: ["Home"].concat(BackupArchiveService.path === "" ? [] : BackupArchiveService.path.split("/"))

                        Row {
                            id: crumb

                            required property string modelData
                            required property int index

                            readonly property bool isLast: crumb.index === crumbRepeater.count - 1
                            spacing: 6

                            Label {
                                visible: crumb.index > 0
                                text: "›"
                                color: Theme.overlay1
                                font.pixelSize: Appearance.fontSize
                            }

                            Label {
                                text: crumb.modelData
                                font.pixelSize: Appearance.fontSize
                                color: crumbMouse.containsMouse || crumb.isLast ? Theme.text : Theme.subtext0

                                MouseArea {
                                    id: crumbMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        const parts = BackupArchiveService.path.split("/");
                                        BackupArchiveService.open(BackupArchiveService.snapshot, parts.slice(0, crumb.index).join("/"));
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    id: filters

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 20

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Only changed"
                        on: BackupArchiveService.onlyChanged

                        onClicked: BackupArchiveService.onlyChanged = !BackupArchiveService.onlyChanged
                    }

                    Link {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "show in Files"

                        onActivated: BackupArchiveService.revealInFiles()
                    }
                }
            }

            // Column headings, aligned with EntryRow.
            Item {
                id: headings

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: toolbar.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 8
                height: 24

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Name"
                    color: Theme.overlay1
                }

                Label {
                    anchors.right: headingDate.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 90
                    horizontalAlignment: Text.AlignRight
                    text: "Size"
                    color: Theme.overlay1
                }

                Label {
                    id: headingDate

                    anchors.right: headingChange.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    horizontalAlignment: Text.AlignRight
                    text: "Modified"
                    color: Theme.overlay1
                }

                Label {
                    id: headingChange

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 160
                    leftPadding: 16
                    text: "In this snapshot"
                    color: Theme.overlay1
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.surface0
                }
            }

            ListView {
                id: entryList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headings.bottom
                anchors.bottom: footer.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 4
                clip: true
                model: BackupArchiveService.visibleEntries
                currentIndex: window.selectedIndex
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 0

                delegate: EntryRow {}

                onCurrentIndexChanged: {
                    if (entryList.currentIndex >= 0)
                        entryList.positionViewAtIndex(entryList.currentIndex, ListView.Contain);
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    visible: text !== ""
                    text: {
                        if (BackupArchiveService.listError !== "")
                            return BackupArchiveService.listError;
                        if (BackupArchiveService.loading && BackupArchiveService.entries.length === 0)
                            return "Reading…";
                        if (BackupArchiveService.snapshot !== "" && BackupArchiveService.visibleEntries.length === 0)
                            return BackupArchiveService.onlyChanged ? "Nothing here changed in this snapshot." : "Empty directory.";
                        return "";
                    }
                    color: BackupArchiveService.listError !== "" ? Theme.red : Theme.subtext0
                }
            }

            Item {
                id: footer

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                height: 40

                Label {
                    anchors.left: parent.left
                    anchors.right: actions.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (BackupArchiveService.notice !== "")
                            return BackupArchiveService.notice;
                        if (window.selected === null)
                            return "";
                        const where = BackupArchiveService.locate(window.selected);
                        return where ? where.home : "";
                    }
                    color: BackupArchiveService.noticeIsError ? Theme.red : (BackupArchiveService.notice !== "" ? Theme.green : Theme.subtext0)
                }

                Row {
                    id: actions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Button {
                        text: "Open"
                        enabled: window.selected !== null

                        onActivated: BackupArchiveService.openEntry(window.selected)
                    }

                    Button {
                        text: "Restore…"
                        enabled: window.selected !== null && !BackupArchiveService.restoring
                        background: Theme.blue
                        hoverBackground: Theme.sapphire
                        foreground: Theme.base

                        onActivated: window.askRestore(window.selected)
                    }
                }
            }
        }

        // The restore confirmation, over everything.
        Rectangle {
            id: confirm

            anchors.fill: parent
            visible: window.confirming !== null
            color: Theme.overlayScrim

            readonly property var entry: window.confirming
            readonly property var where: confirm.entry ? BackupArchiveService.locate(confirm.entry) : null
            readonly property bool exists: confirm.entry?.atHome ?? false

            MouseArea {
                anchors.fill: parent

                onClicked: window.confirming = null
            }

            Rectangle {
                anchors.centerIn: parent
                width: 520
                height: dialog.implicitHeight + 40
                radius: 8
                color: Theme.popupBackground
                border.color: Theme.popupBorder
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: dialog

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        width: parent.width
                        text: `Restore ${confirm.entry?.name ?? ""}`
                        color: Theme.text
                        elide: Text.ElideMiddle
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.fontSize
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        text: {
                            if (confirm.where === null)
                                return "";
                            const from = `from ${confirm.where.snapshot} (${BackupArchiveService.formatSnapshotDay(BackupArchiveService.snapshots.find(s => s.name === confirm.where.snapshot)?.time ?? 0).toLowerCase()})`;
                            if (confirm.exists)
                                return `${confirm.where.home} already exists. Replace it with the copy ${from}, or keep both?`;
                            return `Copy ${from} to ${confirm.where.home}.`;
                        }
                        color: Theme.subtext1
                    }

                    Label {
                        width: parent.width
                        visible: confirm.exists && confirm.entry?.kind === "dir"
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                        text: "Replacing a directory makes it identical to the snapshot: anything added since is removed."
                        color: Theme.yellow
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        Button {
                            text: "Cancel"

                            onActivated: window.confirming = null
                        }

                        Button {
                            visible: confirm.exists
                            text: "Keep both"

                            onActivated: {
                                BackupArchiveService.restore(confirm.entry, "keep");
                                window.confirming = null;
                            }
                        }

                        Button {
                            text: confirm.exists ? "Replace" : "Restore"
                            background: confirm.exists ? Theme.red : Theme.blue
                            hoverBackground: confirm.exists ? Theme.maroon : Theme.sapphire
                            foreground: Theme.base

                            onActivated: {
                                BackupArchiveService.restore(confirm.entry, "replace");
                                window.confirming = null;
                            }
                        }
                    }
                }
            }
        }
    }
}
