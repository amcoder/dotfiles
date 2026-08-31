//@ pragma UseQApplication
import Quickshell

ShellRoot {
    Polkit {}

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
        }
    }
}
