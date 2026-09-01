//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.polkit
import qs.modules.power
import qs.modules.switcher
import qs.modules.theme

ShellRoot {
    NotificationPopups {}

    NotificationCentre {}

    Osd {}

    PolkitDialog {}

    ThemePicker {}

    Launcher {}

    WindowSwitcher {}

    PowerMenu {}

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
        }
    }
}
