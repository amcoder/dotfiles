pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool active: false

    property var themes: []
    property string current: ""

    function show(): void {
        if (root.themes.length === 0)
            return;

        root.active = true;
    }

    function hide(): void {
        Theme.preview = null;
        root.active = false;
    }

    function toggle(): void {
        if (root.active)
            root.hide();
        else
            root.show();
    }

    function commit(name: string): void {
        root.hide();
        apply.command = ["theme", "set", name];
        apply.running = true;
    }

    Process {
        id: apply
    }

    IpcHandler {
        target: "theme"

        function toggle(): void {
            root.toggle();
        }

        function show(): void {
            root.show();
        }

        function hide(): void {
            root.hide();
        }
    }

    FileView {
        id: view

        path: `${Paths.config}/quickshell/themes.json`
        watchChanges: true

        onFileChanged: view.reload()

        onLoaded: {
            try {
                const catalog = JSON.parse(view.text());
                root.themes = catalog.themes ?? [];
                root.current = catalog.current ?? "";
            } catch (error) {
                root.themes = [];
                root.current = "";
            }
        }

        onLoadFailed: {
            root.themes = [];
            root.current = "";
        }
    }
}
