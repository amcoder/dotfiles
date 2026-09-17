import QtQuick
import qs.config

// An icon that is its own gauge: the glyph is drawn in the track colour, and a
// copy in `color` fills it from the bottom up to `value`. `glyphTop` and
// `glyphBottom` are where the glyph's ink starts and ends as fractions of the
// icon's height, so the fill spans what is drawn rather than the whole square.
Item {
    id: root

    required property string name
    property real value: 0
    property color color: Theme.barStatusline
    property color trackColor: Theme.surface2
    property int size: Appearance.iconSize
    property real glyphTop: 0
    property real glyphBottom: 1

    readonly property real fraction: Math.min(1, Math.max(0, root.value))

    implicitWidth: root.size
    implicitHeight: root.size

    Icon {
        anchors.fill: parent
        name: root.name
        size: root.size
        color: root.trackColor
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.size * ((1 - root.glyphBottom) + (root.glyphBottom - root.glyphTop) * root.fraction)
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Icon {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            name: root.name
            size: root.size
            color: root.color
        }
    }
}
