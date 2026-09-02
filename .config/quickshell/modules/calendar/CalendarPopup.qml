import QtQuick
import qs.config
import qs.widgets
import qs.windows

// The month grid the clock drops down. Hand-rolled from `Date` rather than
// pulling in QtQuick.Controls for its one calendar type: the whole of it is
// the 42 cells below.
BarPopup {
    id: root

    // Today, fed from the bar's own clock so the highlight moves at midnight
    // without a second timer.
    required property date now

    property int year: 0
    property int month: 0

    cardWidth: 320

    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek

    readonly property var weekdays: {
        const locale = Qt.locale();
        const out = [];
        for (let i = 0; i < 7; i++)
            out.push(locale.dayName((root.firstDayOfWeek + i) % 7, Locale.ShortFormat));
        return out;
    }

    // Always six rows, even for the months that fit in five: a grid that
    // changes height would move the card's own edges as you page through it.
    readonly property var cells: {
        const first = new Date(root.year, root.month, 1);
        const offset = (first.getDay() - root.firstDayOfWeek + 7) % 7;
        const out = [];

        for (let i = 0; i < 42; i++)
            out.push(new Date(root.year, root.month, 1 - offset + i));

        return out;
    }

    function reset(): void {
        root.year = root.now.getFullYear();
        root.month = root.now.getMonth();
    }

    function shift(months: int): void {
        const target = new Date(root.year, root.month + months, 1);
        root.year = target.getFullYear();
        root.month = target.getMonth();
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // Opens on the current month however far it was paged last time.
    onExpandedChanged: {
        if (root.expanded)
            root.reset();
    }

    Component.onCompleted: root.reset()

    component Step: MouseArea {
        id: step

        required property string icon

        signal activated

        implicitWidth: 28
        implicitHeight: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: step.activated()

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: step.containsMouse ? Theme.popupHover : "transparent"
        }

        Icon {
            anchors.centerIn: parent
            name: step.icon
            size: Appearance.smallFontSize + 4
            color: Theme.popupText
        }
    }

    Item {
        width: parent.width
        implicitHeight: 28

        Step {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "caret-left"

            onActivated: root.shift(-1)
        }

        // Clicking the month name is the way back to today, which is otherwise
        // several presses away once you have paged into next year.
        MouseArea {
            anchors.centerIn: parent
            implicitWidth: heading.implicitWidth + 16
            implicitHeight: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: root.reset()

            Text {
                id: heading

                anchors.centerIn: parent
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
            }
        }

        Step {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "caret-right"

            onActivated: root.shift(1)
        }
    }

    Grid {
        width: parent.width
        columns: 7

        Repeater {
            model: root.weekdays

            Text {
                required property string modelData

                width: parent.width / 7
                height: 22
                text: modelData
                color: Theme.popupSubtext
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }

        Repeater {
            model: root.cells

            Item {
                id: cell

                required property date modelData

                readonly property bool today: root.sameDay(cell.modelData, root.now)
                readonly property bool inMonth: cell.modelData.getMonth() === root.month

                width: parent.width / 7
                height: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: width / 2
                    visible: cell.today
                    color: Theme.blue
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.getDate()
                    color: {
                        if (cell.today)
                            return Theme.crust;
                        return cell.inMonth ? Theme.popupText : Theme.overlay0;
                    }
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.smallFontSize
                }
            }
        }
    }
}
