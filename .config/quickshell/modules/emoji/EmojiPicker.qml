import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.windows

// The emoji picker, replacing `bemoji -c -n` and the bemenu it drew itself in.
// wtype stays: picking still copies and then pastes, which is what the sway
// binding always did.
Scope {
    id: root

    readonly property int rowHeight: 40

    function activate(item: var): void {
        // Both of these must run inside this handler, before the overlay goes:
        // the clipboard write needs the seat's current input serial, which only
        // a key or click event provides.
        EmojiService.copy(item.glyph);
        EmojiService.paste();
    }

    ModalOverlay {
        namespaceSuffix: "emoji"

        visible: EmojiService.active
        closeOnClickOutside: true
        cardWidth: 560
        focusItem: list

        onDismissed: EmojiService.hide()

        onOpened: list.reset()

        Row {
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "🔍"
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Emoji"
                color: Theme.popupText
                font.family: Appearance.fontFamily
                font.pixelSize: Appearance.headingFontSize
            }
        }

        FilterList {
            id: list

            width: parent.width
            placeholder: "Search emoji"
            rowHeight: root.rowHeight
            maxRows: 10
            fixedHeight: true

            source: EmojiService.entries

            // The glyph as well as the name, so pasting one back into the field
            // finds it again.
            fields: item => [item.name, item.glyph]
            weight: item => EmojiService.frecency(item.glyph)

            onAccepted: item => root.activate(item)
            onCancelled: EmojiService.hide()

            delegate: ListRow {
                id: row

                required property int index
                required property var modelData

                width: list.width
                height: root.rowHeight
                margins: 2
                selected: row.ListView.isCurrentItem

                onEntered: row.ListView.view.currentIndex = row.index
                onActivated: root.activate(row.modelData)

                Text {
                    id: glyph

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    text: row.modelData.glyph
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Appearance.fontSize
                }

                Text {
                    anchors.left: glyph.right
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: Theme.popupText
                    elide: Text.ElideRight
                    font.family: Appearance.fontFamily
                    font.pixelSize: Appearance.fontSize
                }
            }
        }
    }
}
