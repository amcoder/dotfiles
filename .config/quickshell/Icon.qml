import QtQuick

Item {
    id: root

    required property string name
    property color color: Theme.barStatusline
    property int size: Theme.iconSize

    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        anchors.fill: parent
        sourceSize.width: root.size
        sourceSize.height: root.size
        smooth: true

        source: {
            const svg = Icons.source(root.name);
            if (svg === "")
                return "";
            return "data:image/svg+xml;base64," + Qt.btoa(svg.replace("#ffffff", root.color.toString()));
        }
    }
}
