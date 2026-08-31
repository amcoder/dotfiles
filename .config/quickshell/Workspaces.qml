import QtQuick
import Quickshell
import Quickshell.I3

Row {
    id: root

    required property string screenName

    readonly property var workspaces: I3.workspaces.values.filter(ws => ws.monitor && ws.monitor.name === root.screenName).sort((a, b) => a.number - b.number)

    spacing: 4

    // Sway workspace names look like "3: 3 <span foreground='#eed49f'>terminal-window</span>":
    // the leading "N:" is the sort key sway strips from the bar, the rest is the
    // label followed by a coloured span naming an icon in icons/.
    function parseName(name) {
        const stripped = name.replace(/^\s*\d+\s*:\s*/, "");
        const span = /<span[^>]*foreground='([^']*)'[^>]*>(.*?)<\/span>/.exec(stripped);

        if (!span)
            return { label: stripped.trim(), icon: "", iconColor: "transparent" };

        return {
            label: stripped.slice(0, span.index).trim(),
            icon: span[2].trim(),
            iconColor: span[1]
        };
    }

    Repeater {
        model: root.workspaces

        Rectangle {
            id: item

            required property var modelData

            readonly property var parsed: root.parseName(item.modelData.name)
            readonly property color foreground: {
                if (item.modelData.urgent)
                    return Theme.base;
                if (item.modelData.focused)
                    return Theme.text;
                return Theme.surface1;
            }

            height: root.height
            implicitWidth: Math.max(44, content.implicitWidth + 16)
            radius: 4

            color: {
                if (item.modelData.urgent)
                    return Theme.red;
                if (item.modelData.focused)
                    return Theme.mantle;
                if (item.modelData.active)
                    return Theme.mantle;
                if (mouse.containsMouse)
                    return Theme.surface0;
                return Theme.base;
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: item.parsed.label !== ""
                    text: item.parsed.label
                    color: item.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: item.parsed.icon !== ""
                    name: item.parsed.icon
                    color: item.modelData.urgent ? Theme.base : item.parsed.iconColor
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: I3.dispatch(`workspace number ${item.modelData.number}`)
            }
        }
    }
}
