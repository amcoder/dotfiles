import QtQuick
import qs.config

// A filled line graph of one or more series over a fixed window. Each series
// is an array of `capacity` samples at most, newest last, drawn right-aligned
// so a window that is not yet full grows in from the right. `max` is the top
// of the graph, or 0 to fit the largest sample.
Rectangle {
    id: root

    property var series: []
    property var colors: [Theme.blue]
    property int capacity: 60
    property real max: 1

    implicitHeight: 56
    radius: 4
    color: Theme.surface0

    onSeriesChanged: canvas.requestPaint()
    onColorsChanged: canvas.requestPaint()
    onMaxChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        anchors.margins: 1

        onWidthChanged: canvas.requestPaint()
        onHeightChanged: canvas.requestPaint()

        onPaint: {
            const ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            let top = root.max;
            if (top <= 0) {
                for (const samples of root.series)
                    for (const sample of samples)
                        top = Math.max(top, sample);
            }
            if (top <= 0)
                return;

            const step = canvas.width / Math.max(1, root.capacity - 1);

            for (let i = 0; i < root.series.length; i++) {
                const samples = root.series[i];
                if (samples.length < 2)
                    continue;

                const colour = root.colors[i % root.colors.length];
                const offset = root.capacity - samples.length;
                const y = value => canvas.height - Math.min(1, value / top) * (canvas.height - 2) - 1;

                ctx.beginPath();
                ctx.moveTo(offset * step, y(samples[0]));
                for (let j = 1; j < samples.length; j++)
                    ctx.lineTo((offset + j) * step, y(samples[j]));

                ctx.lineWidth = 1.5;
                ctx.strokeStyle = colour;
                ctx.stroke();

                ctx.lineTo((offset + samples.length - 1) * step, canvas.height);
                ctx.lineTo(offset * step, canvas.height);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(colour.r, colour.g, colour.b, 0.25);
                ctx.fill();
            }
        }
    }
}
