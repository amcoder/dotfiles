pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string directory: Qt.resolvedUrl("../icons").toString().replace(/^file:\/\//, "")
    readonly property var cache: ({})

    // Returns the raw SVG markup for an icon in icons/, which Icon.qml recolours
    // by substituting the placeholder fill.
    function source(name: string): string {
        if (name === "")
            return "";
        if (root.cache[name] !== undefined)
            return root.cache[name];

        const view = reader.createObject(root, {
            path: `${root.directory}/${name}.svg`
        });
        const svg = view.text();
        view.destroy();

        root.cache[name] = svg;
        return svg;
    }

    Component {
        id: reader

        FileView {
            blockLoading: true
        }
    }
}
