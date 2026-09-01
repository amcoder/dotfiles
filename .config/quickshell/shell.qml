//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.polkit
import qs.modules.theme

ShellRoot {
    PolkitDialog {}

    ThemePicker {}

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
        }
    }
}
