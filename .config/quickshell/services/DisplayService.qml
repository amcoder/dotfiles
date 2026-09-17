pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

// Every output sway knows about and what can be done to it: mode, scale,
// enable and disable, and for an ultrawide the swap between its native shape
// and the best conventional mode that fits inside it.
//
// Two reads feed this. `get_outputs` is what sway reports -- the modes on
// offer and the current state -- and `sway-outputs json` is what the ladder
// resolves for each one: the native mode, the default scale and the 16:9
// alternative. Keeping that second answer in the script rather than here is
// what keeps this panel, `sway-scale default` and `sway-toggle-aspect` in
// agreement about what "default" means.
//
// Every command goes through sway's `output` directive and only when it is a
// real change. Re-committing an output is a full modeset, which is the path
// that wedges this GPU (see .claude/sway-lockup-investigation.md).
Singleton {
    id: root

    // The scales the panel offers. The current scale is added when it is not
    // one of these, so a `sway-scale up` value still shows as selected.
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]

    // An output whose native mode is this wide or wider gets the aspect swap.
    // 21:9 is 2.33 and 32:9 is 3.56; 16:10 is 1.6 and 16:9 1.78.
    readonly property real ultrawideAspect: 2

    property var ipc: []
    property var resolved: ({})

    readonly property var outputs: root.ipc.map(output => root.describe(output))
    readonly property int activeCount: root.outputs.filter(output => output.active).length

    function refresh(): void {
        ipcRead.running = true;
        ladderRead.running = true;
    }

    function modeString(width: int, height: int, refresh: int): string {
        return `${width}x${height}@${(refresh / 1000).toFixed(3)}Hz`;
    }

    // "5120x1440@240.000Hz" into its parts, or null.
    function parseMode(mode: var): var {
        const match = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(mode ?? "");
        if (match === null)
            return null;

        return {
            width: Number(match[1]),
            height: Number(match[2]),
            refresh: Math.round(Number(match[3]) * 1000)
        };
    }

    function sameResolution(a: var, b: var): bool {
        return a !== null && b !== null && a.width === b.width && a.height === b.height;
    }

    // The IPC object plus the ladder's answers and everything the panel draws
    // from them. A disabled output carries no modes, so most of this is empty
    // for one.
    function describe(output: var): var {
        const ladder = root.resolved[output.name] ?? {};
        const nativeMode = root.parseMode(ladder.mode);
        const conventional = root.parseMode(ladder.conventional);
        const current = output.current_mode ?? null;
        const modes = (output.modes ?? []).filter(mode => mode.width > 0 && mode.height > 0);

        const resolutions = [];
        for (const mode of modes) {
            let entry = resolutions.find(r => r.width === mode.width && r.height === mode.height);
            if (entry === undefined) {
                entry = {
                    width: mode.width,
                    height: mode.height,
                    refreshes: []
                };
                resolutions.push(entry);
            }
            if (entry.refreshes.indexOf(mode.refresh) < 0)
                entry.refreshes.push(mode.refresh);
        }
        resolutions.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.width - a.width));
        for (const entry of resolutions)
            entry.refreshes.sort((a, b) => b - a);

        const description = [output.make, output.model].filter(part => part && part !== "Unknown").join(" ");
        const scale = output.scale ?? 1;
        const ultrawide = nativeMode !== null && conventional !== null
            && nativeMode.width / nativeMode.height >= root.ultrawideAspect
            && !root.sameResolution(nativeMode, conventional);

        return {
            name: output.name,
            identifier: [output.make, output.model, output.serial].filter(part => part).join(" "),
            description: description,
            internal: /^(eDP|LVDS|DSI)/.test(output.name),
            active: output.active === true,
            power: output.power === true,
            focused: output.focused === true,
            current: current,
            scale: scale,
            logicalWidth: current ? Math.round(current.width / scale) : 0,
            logicalHeight: current ? Math.round(current.height / scale) : 0,
            resolutions: resolutions,
            nativeMode: nativeMode,
            conventional: conventional,
            defaultScale: ladder.scale ?? null,
            ultrawide: ultrawide,
            // Compared on resolution alone, as sway-toggle-aspect does: the
            // refresh in a mode string is rounded, and only the shape matters.
            atNative: root.sameResolution(current, nativeMode),
            atNativeMode: root.sameResolution(current, nativeMode) && current.refresh === nativeMode.refresh,
            atDefaultScale: ladder.scale !== undefined && Math.abs(scale - ladder.scale) < 0.001
        };
    }

    function setMode(output: var, width: int, height: int, refresh: int): void {
        const current = output.current;
        if (current && current.width === width && current.height === height && current.refresh === refresh)
            return;

        I3.dispatch(`output ${output.name} mode ${root.modeString(width, height, refresh)}`);
    }

    // The highest refresh at a resolution, which is what picking a resolution
    // means; the refresh chips then narrow it.
    function setResolution(output: var, resolution: var): void {
        root.setMode(output, resolution.width, resolution.height, resolution.refreshes[0]);
    }

    function setScale(output: var, scale: real): void {
        if (Math.abs(output.scale - scale) < 0.001)
            return;

        I3.dispatch(`output ${output.name} scale ${scale}`);
    }

    // The last active output is never disabled from here: sway would carry on
    // with nowhere to draw, and this panel would be gone with everything else.
    function canDisable(output: var): bool {
        return output.active && root.activeCount > 1;
    }

    function setEnabled(output: var, enabled: bool): void {
        if (output.active === enabled)
            return;
        if (!enabled && !root.canDisable(output))
            return;

        I3.dispatch(`output ${output.name} ${enabled ? "enable" : "disable"}`);
    }

    // Native shape to the conventional one and back; from any third mode, back
    // to native.
    function toggleAspect(output: var): void {
        const target = output.atNative ? output.conventional : output.nativeMode;
        if (target === null)
            return;

        root.setMode(output, target.width, target.height, target.refresh);
    }

    // Back to what the ladder would have chosen, in one commit rather than two.
    function reset(output: var): void {
        const parts = [];
        if (output.nativeMode !== null && !output.atNativeMode)
            parts.push(`mode ${root.modeString(output.nativeMode.width, output.nativeMode.height, output.nativeMode.refresh)}`);
        if (output.defaultScale !== null && !output.atDefaultScale)
            parts.push(`scale ${output.defaultScale}`);

        if (parts.length === 0)
            return;

        I3.dispatch(`output ${output.name} ${parts.join(" ")}`);
    }

    Process {
        id: ipcRead

        running: true
        command: ["swaymsg", "-r", "-t", "get_outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.ipc = JSON.parse(this.text);
                } catch (error) {
                    root.ipc = [];
                }
            }
        }
    }

    Process {
        id: ladderRead

        running: true
        command: ["sway-outputs", "json"]

        stdout: StdioCollector {
            onStreamFinished: {
                const byName = {};
                try {
                    for (const entry of JSON.parse(this.text))
                        byName[entry.name] = entry;
                } catch (error) {
                }
                root.resolved = byName;
            }
        }
    }

    // A hotplug or a modeset arrives as a burst of output events; read once,
    // at the end of it.
    Timer {
        id: settle

        interval: 300

        onTriggered: root.refresh()
    }

    Process {
        running: true
        command: ["swaymsg", "-r", "-m", "-t", "subscribe", '["output"]']

        stdout: SplitParser {
            onRead: line => settle.restart()
        }
    }
}
