//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.notifications
import qs.modules.polkit
import qs.modules.theme

ShellRoot {
    NotificationPopups {}

    NotificationCentre {}

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
