import QtQuick
import Quickshell.Io
import qs.config
import qs.widgets
import qs.windows

MouseArea {
    id: root

    readonly property int refreshInterval: 3600000

    property var packages: []
    property var selected: ({})
    property bool upgrading: false
    property int upgradingCount: 0
    property string upgradeOutput: ""
    property string upgradeErrors: ""
    property string upgradeError: ""
    property string upgradeMessage: ""

    readonly property int count: root.packages.length
    readonly property int selectedCount: Object.keys(root.selected).length

    readonly property string headerText: {
        if (root.upgrading)
            return root.upgradingCount === 1 ? "Upgrading 1 package…" : `Upgrading ${root.upgradingCount} packages…`;
        if (root.upgradeError !== "")
            return root.upgradeError;
        if (root.upgradeMessage !== "")
            return root.upgradeMessage;
        return root.count === 1 ? "1 package to upgrade" : `${root.count} packages to upgrade`;
    }

    readonly property color headerColor: {
        if (root.upgradeError !== "")
            return Theme.red;
        if (root.upgradeMessage !== "")
            return Theme.green;
        return Theme.popupText;
    }

    // dpkg has no stdin, so a changed config file aborts the transaction with
    // "EOF on stdin at conffile prompt" rather than silently keeping either version.
    function failureReason(exitCode) {
        // pkexec exits 126/127 when the prompt is dismissed or authorization is denied.
        if (exitCode === 126 || exitCode === 127)
            return "Authentication failed";

        const lines =(root.upgradeErrors + "\n" + root.upgradeOutput).split("\n").map(line => line.trim()).filter(line => line !== "");

        const conffile = lines.find(line => /^Configuration file '/.test(line));
        if (conffile !== undefined)
            return `Config file conflict: ${/'([^']*)'/.exec(conffile)[1]}`;

        const dpkgError = lines.find(line => /^dpkg: error processing package /.test(line));
        if (dpkgError !== undefined)
            return `dpkg failed on ${/package (\S+)/.exec(dpkgError)[1]}`;

        const aptError = lines.find(line => line.startsWith("E: "));
        if (aptError !== undefined)
            return aptError;

        const stderrLines = root.upgradeErrors.split("\n").map(line => line.trim()).filter(line => line !== "");
        if (stderrLines.length > 0)
            return stderrLines[stderrLines.length - 1];

        return `Upgrade failed (exit code ${exitCode})`;
    }

    function isSelected(name) {
        return root.selected[name] === true;
    }

    function toggle(name) {
        const next = Object.assign({}, root.selected);

        if (next[name])
            delete next[name];
        else
            next[name] = true;

        root.selected = next;
    }

    function selectAll() {
        const next = {};

        for (const pkg of root.packages) {
            next[pkg.name] = true;
        }

        root.selected = next;
    }

    function clearSelection() {
        root.selected = ({});
    }

    function upgradeSelected() {
        const names = root.packages.map(pkg => pkg.name).filter(name => root.isSelected(name));

        if (names.length === 0)
            return;

        root.upgradingCount = names.length;
        root.upgradeOutput = "";
        root.upgradeErrors = "";
        root.upgradeError = "";
        root.upgradeMessage = "";
        root.upgrading = true;

        upgrade.command = ["pkexec", "sh", "-c", "DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade \"$@\"", "sh"].concat(names);
        upgrade.running = true;
    }

    visible: root.count > 0
    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: {
        if (popup.expanded) {
            popup.expanded = false;
        } else {
            if (!root.upgrading)
                check.running = true;
            popup.expanded = true;
        }
    }

    onCountChanged: {
        if (root.count === 0)
            popup.expanded = false;
    }

    Process {
        id: check

        running: true
        // Upgradable lines look like "Inst bash [5.3-3] (5.3-3+b1 Debian:unstable [amd64])";
        // new installs have no [old version] and are skipped.
        command: ["sh", "-c", "apt-get -sq upgrade | sed -n 's/^Inst \\([^ ]*\\) \\[\\([^]]*\\)\\] (\\([^ ]*\\).*/\\1\\t\\2\\t\\3/p' | LC_ALL=C sort"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.packages = this.text.trim().split("\n").filter(line => line !== "").map(line => {
                    const fields = line.split("\t");
                    return {
                        name: fields[0],
                        from: fields[1],
                        to: fields[2]
                    };
                });

                const remaining = {};
                for (const pkg of root.packages) {
                    if (root.isSelected(pkg.name))
                        remaining[pkg.name] = true;
                }
                root.selected = remaining;
                root.upgradeMessage = "";
            }
        }
    }

    Process {
        id: upgrade

        stdout: StdioCollector {
            onStreamFinished: root.upgradeOutput = this.text
        }

        stderr: StdioCollector {
            onStreamFinished: root.upgradeErrors = this.text
        }

        onExited: exitCode => {
            root.upgrading = false;

            if (exitCode === 0) {
                root.upgradeError = "";
                root.upgradeMessage = root.upgradingCount === 1 ? "Upgraded 1 package" : `Upgraded ${root.upgradingCount} packages`;
                root.clearSelection();
                check.running = true;
            } else {
                root.upgradeError = root.failureReason(exitCode);
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: true

        onTriggered: {
            if (!root.upgrading)
                check.running = true;
        }
    }

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "package"
            color: root.upgrading ? Theme.yellow : Theme.barStatusline
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            color: root.upgrading ? Theme.yellow : Theme.barStatusline
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.fontSize
        }
    }

    BarPopup {
        id: popup

        readonly property int rowHeight: 26
        readonly property int maxRows: 20

        anchorItem: root
        cardWidth: 560
        spacing: 8

        Item {
            id: header

            width: parent.width
            height: 30

            Icon {
                id: headerIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "package"
                color: root.headerColor
            }

            Text {
                anchors.left: headerIcon.right
                anchors.right: actions.left
                anchors.leftMargin: 6
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.headerText
                color: root.headerColor
                elide: Text.ElideRight
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
            }

            Row {
                id: actions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    id: selectLink

                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.upgrading
                    text: root.selectedCount > 0 ? "clear" : "select all"
                    color: selectMouse.containsMouse ? Theme.popupText : Theme.popupSubtext
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize

                    MouseArea {
                        id: selectMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (root.selectedCount > 0)
                                root.clearSelection();
                            else
                                root.selectAll();
                        }
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.selectedCount > 0 && !root.upgrading
                    implicitWidth: upgradeLabel.implicitWidth + 20
                    height: 26
                    radius: 4
                    color: upgradeMouse.containsMouse ? Theme.sapphire : Theme.blue

                    Text {
                        id: upgradeLabel

                        anchors.centerIn: parent
                        text: `Upgrade ${root.selectedCount}`
                        color: Theme.base
                        font.family: Appearance.fontFamily
                        font.pixelSize: Appearance.smallFontSize
                    }

                    MouseArea {
                        id: upgradeMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.upgradeSelected()
                    }
                }
            }
        }

        // The card grows with the list until it hits `maxRows`, which is what
        // the popup's fixed height used to cap.
        ListView {
            id: list

            width: parent.width
            height: Math.min(list.contentHeight, popup.maxRows * popup.rowHeight)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.packages

            delegate: ListRow {
                id: entry

                required property var modelData

                readonly property bool checked: root.isSelected(entry.modelData.name)

                width: list.width
                height: popup.rowHeight
                enabled: !root.upgrading
                selected: entry.checked

                onActivated: root.toggle(entry.modelData.name)

                Rectangle {
                    id: box

                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 3
                    color: entry.checked ? Theme.blue : "transparent"
                    border.color: entry.checked ? Theme.blue : Theme.surface2
                    border.width: 1
                }

                Text {
                    anchors.left: box.right
                    anchors.right: versions.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.name
                    color: Theme.popupText
                    elide: Text.ElideRight
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }

                Text {
                    id: versions

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${entry.modelData.from} → ${entry.modelData.to}`
                    color: Theme.popupSubtext
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }
            }
        }
    }
}
