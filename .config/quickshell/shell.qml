//@ pragma UseQApplication
import Quickshell

ShellRoot {
    Polkit {}

    ThemePicker {}

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
        }
    }
}
