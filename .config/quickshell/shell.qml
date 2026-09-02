//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.idle
import qs.modules.launcher
import qs.modules.network
import qs.modules.notifications
import qs.modules.osd
import qs.modules.polkit
import qs.modules.power
import qs.modules.switcher
import qs.modules.theme
import qs.windows

ShellRoot {
    NotificationPopups {}

    NotificationCentre {}

    Osd {}

    PolkitDialog {}

    ThemePicker {}

    Launcher {}

    WindowSwitcher {}

    PowerMenu {}

    PskDialog {}

    Variants {
        model: Quickshell.screens

        Wallpaper {
            required property var modelData

            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        IdleDim {
            required property var modelData

            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
        }
    }
}
