import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The session menu the bar's power icon drops down. One per bar, since it
// hangs off that icon; the focused-screen gate is what keeps a single menu
// open when there is more than one bar.
BarPopup {
    id: root

    readonly property int rowHeight: 46

    namespaceSuffix: "power-menu"

    cardWidth: 420
    focusItem: list

    onDismissed: PowerService.cancel()

    onOpened: list.reset()

    // Assigned rather than bound: BarPopup clears `expanded` when the card is
    // dismissed, and an assignment to a bound property breaks the binding for
    // good.
    Connections {
        target: PowerService

        function onActiveChanged(): void {
            root.expanded = PowerService.active && root.screen === FocusedScreen.screen;
        }
    }

    Row {
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "power"
            color: Theme.red
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Session"
            color: Theme.popupText
            font.family: Appearance.fontFamily
            font.pixelSize: Appearance.headingFontSize
        }
    }

    FilterList {
        id: list

        width: parent.width
        searchable: false
        rowHeight: root.rowHeight
        maxRows: PowerService.actions.length

        source: PowerService.actions
        fields: action => [action.label]

        onAccepted: action => PowerService.choose(action)
        onCancelled: PowerService.cancel()

        // The mnemonics of the sway mode this replaces: a bare letter picks
        // its action, so the muscle memory carries over.
        Keys.onPressed: event => {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
                return;

            const action = PowerService.actions.find(candidate => candidate.key === event.text);
            if (action === undefined)
                return;

            PowerService.choose(action);
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
            onActivated: PowerService.choose(row.modelData)

            Icon {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                name: row.modelData.icon
                color: row.modelData.colour
            }

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 48
                text: row.modelData.label
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.fontSize
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 14
                text: row.modelData.key
                color: Theme.popupSubtext
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.smallFontSize
            }
        }
    }
}
