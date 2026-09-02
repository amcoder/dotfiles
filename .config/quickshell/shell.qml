//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.idle
import qs.modules.launcher
import qs.modules.osd
import qs.modules.polkit
import qs.modules.power
import qs.modules.switcher
import qs.modules.theme
import qs.windows

ShellRoot {
    Osd {}

    PolkitDialog {}

    ThemePicker {}

    Launcher {}

    WindowSwitcher {}

    PowerMenu {}

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
