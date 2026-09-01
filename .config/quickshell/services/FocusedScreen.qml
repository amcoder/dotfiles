pragma Singleton

import Quickshell
import Quickshell.I3

// The output holding the focused sway workspace, which is where every modal
// surface draws. Falls back to the first screen: a PanelWindow bound to a null
// screen fails to map with "no output to auto-assign layer surface to".
Singleton {
    id: root

    readonly property var screen: {
        const workspace = I3.workspaces.values.find(ws => ws.focused);
        const name = workspace && workspace.monitor ? workspace.monitor.name : "";

        for (const output of Quickshell.screens) {
            if (output.name === name)
                return output;
        }

        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }
}
