import QtQuick
import QtQuick.Shapes
import qs.config

// The outline of a card hung from the bar: the top edge is filled but not
// stroked, and the top corners curve the other way to the bottom ones, flaring
// `flare` px past each side so the card's walls grow out of the surface above
// instead of closing into a box.
//
// A Shape rather than a Rectangle, because the notch beside each flare has to
// be genuinely transparent and nothing drawn on top of a rectangle can cut a
// hole in it. The path is left open along the top: an unclosed subpath is
// still filled, which is what paints that edge without stroking it.
//
// It overflows its parent by the flare on either side, so the parent must not
// clip -- put the clip on an inner item instead.
Shape {
    id: root

    property color fillColor: Theme.barBackground
    property color strokeColor: Theme.popupBorder
    property int cornerRadius: 6
    property int flare: 10

    readonly property real cardWidth: root.width - root.flare * 2
    readonly property real curve: Math.min(root.flare, root.height / 2)
    readonly property real corner: Math.min(root.cornerRadius, root.cardWidth / 2, root.height - root.curve)

    anchors.fill: parent
    anchors.leftMargin: -root.flare
    anchors.rightMargin: -root.flare
    visible: root.height > 0
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fillColor
        strokeColor: root.strokeColor
        strokeWidth: 1

        startX: root.flare - root.curve
        startY: 0

        PathArc {
            x: root.flare
            y: root.curve
            radiusX: root.curve
            radiusY: root.curve
            direction: PathArc.Clockwise
        }

        PathLine {
            x: root.flare
            y: root.height - root.corner
        }

        PathArc {
            x: root.flare + root.corner
            y: root.height
            radiusX: root.corner
            radiusY: root.corner
            direction: PathArc.Counterclockwise
        }

        PathLine {
            x: root.flare + root.cardWidth - root.corner
            y: root.height
        }

        PathArc {
            x: root.flare + root.cardWidth
            y: root.height - root.corner
            radiusX: root.corner
            radiusY: root.corner
            direction: PathArc.Counterclockwise
        }

        PathLine {
            x: root.flare + root.cardWidth
            y: root.curve
        }

        PathArc {
            x: root.flare + root.cardWidth + root.curve
            y: 0
            radiusX: root.curve
            radiusY: root.curve
            direction: PathArc.Clockwise
        }
    }
}
