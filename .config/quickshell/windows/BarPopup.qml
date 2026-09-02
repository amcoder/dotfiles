import QtQuick
import Quickshell
import qs.services

// The card a bar item drops down. Children stack in a column inside `padding`,
// and the card sizes itself to them.
//
// This is an overlay layer surface rather than a PopupWindow, and that is the
// whole point of the file. A PopupWindow can never hold keyboard focus: keys
// go to the parent layer surface, which is a different window, so a text field
// in one shows a caret and then never receives a character, Escape never
// arrives, and both keys and clicks fall through to whatever is underneath the
// bar. A layer surface with exclusive focus has none of those problems, and it
// is also free to resize while open, which an xdg_popup is not.
ModalOverlay {
    id: root

    function toggle(): void {
        root.visible = !root.visible;
    }

    namespaceSuffix: "bar-popup"

    // A PanelWindow is visible by default; a dropdown is not. Without this
    // every panel maps at startup as a full-screen overlay and swallows the
    // clicks meant for the bar.
    visible: false

    // The screen whose bar was clicked, rather than whichever holds the focus.
    // Falls back rather than resolving to null: a PanelWindow with no screen
    // fails to map at all.
    screen: root.anchorItem?.QsWindow.window?.screen ?? FocusedScreen.screen

    dim: false
    closeOnClickOutside: true
    cardWidth: 360
    padding: 12
    spacing: 12

    onDismissed: root.visible = false
}
