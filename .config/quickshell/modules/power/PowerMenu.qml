import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.windows

Scope {
    id: root

    readonly property int rowHeight: 46

    ModalOverlay {
        namespaceSuffix: "power-menu"

        visible: PowerService.active
        closeOnClickOutside: true
        cardWidth: 420
        focusItem: list

        onDismissed: PowerService.cancel()

        onOpened: list.reset()

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

    CountdownDialog {
        visible: PowerService.pending !== null

        title: PowerService.pending ? PowerService.pending.label : ""
        acceptText: PowerService.pending ? PowerService.pending.label : ""
        countdown: PowerService.confirmSeconds

        onAccepted: PowerService.confirm()
        onRejected: PowerService.cancel()
    }
}
