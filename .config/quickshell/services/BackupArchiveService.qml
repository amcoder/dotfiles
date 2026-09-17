pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The snapshots on the NAS, for the backup browser: the list of them, the
// listing of one directory in one of them with what changed since the
// snapshot before, and restoring an entry. Every read goes through
// `backup-browse` in a Process, so a NAS that is slow or away never stalls
// the window; the automount is `soft`, so it fails rather than hangs.
//
// Only the browser process references this, so the bar never creates it.
Singleton {
    id: root

    property string archive: ""
    property var snapshots: []
    property string snapshotsError: ""
    readonly property bool loadingSnapshots: snapshotReader.running

    // The snapshot and the directory inside it that the window shows.
    property string snapshot: ""
    property string path: ""
    property var previous: null
    property var entries: []
    property string listError: ""
    readonly property bool loading: lister.running

    property bool onlyChanged: false

    readonly property var visibleEntries: root.onlyChanged ? root.entries.filter(e => e.change !== null && e.change !== "same") : root.entries

    // The outcome of the last restore, for the footer.
    property string notice: ""
    property bool noticeIsError: false
    readonly property bool restoring: restorer.running

    signal restored(string dest)

    readonly property var snapshotInfo: root.snapshots.find(s => s.name === root.snapshot) ?? null

    function refreshSnapshots(): void {
        snapshotReader.running = true;
    }

    function open(snapshot: string, path: string): void {
        root.snapshot = snapshot;
        root.path = path;
        root.notice = "";
        root.list();
    }

    // One read at a time: a request arriving while one is in flight waits
    // for it, and the earlier reply is dropped.
    function list(): void {
        if (lister.running) {
            lister.stale = true;
            return;
        }
        lister.stale = false;
        lister.command = ["backup-browse", "list", root.snapshot, root.path];
        lister.running = true;
    }

    function reload(): void {
        if (root.snapshot !== "")
            root.open(root.snapshot, root.path);
    }

    function enter(name: string): void {
        root.open(root.snapshot, root.path === "" ? name : `${root.path}/${name}`);
    }

    function up(): void {
        if (root.path === "")
            return;
        const parts = root.path.split("/");
        parts.pop();
        root.open(root.snapshot, parts.join("/"));
    }

    // The absolute path of an entry as it sits on the NAS. A deleted entry
    // exists only in the previous snapshot, which is where it is read from.
    function locate(entry: var): var {
        const snapshot = entry.change === "deleted" ? root.previous?.name : root.snapshot;
        if (!snapshot)
            return null;
        const rel = root.path === "" ? entry.name : `${root.path}/${entry.name}`;
        return {
            snapshot: snapshot,
            rel: rel,
            file: `${root.archive}/${snapshot}/${rel}`,
            home: `${Quickshell.env("HOME")}/${rel}`
        };
    }

    function openEntry(entry: var): void {
        const where = root.locate(entry);
        if (where !== null)
            Quickshell.execDetached(["xdg-open", where.file]);
    }

    function revealInFiles(): void {
        if (root.snapshot !== "")
            Quickshell.execDetached(["nautilus", "--new-window", `${root.archive}/${root.snapshot}/${root.path}`]);
    }

    function restore(entry: var, mode: string): void {
        const where = root.locate(entry);
        if (where === null || restorer.running)
            return;
        root.notice = "";
        restorer.entryName = entry.name;
        restorer.command = ["backup-browse", "restore", where.snapshot, where.rel, mode];
        restorer.running = true;
    }

    function formatSize(bytes: var): string {
        if (bytes === null || bytes === undefined)
            return "";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return `${value.toFixed(value >= 100 || unit === 0 ? 0 : 1)} ${units[unit]}`;
    }

    function formatDate(epoch: real): string {
        const date = new Date(epoch * 1000);
        const now = new Date();
        if (date.getFullYear() === now.getFullYear())
            return Qt.formatDateTime(date, "d MMM HH:mm");
        return Qt.formatDateTime(date, "d MMM yyyy HH:mm");
    }

    // "Today 00:11", "Yesterday 00:02", "Mon 14 Sep", "4 Sep 2026".
    function formatSnapshotDay(epoch: real): string {
        const date = new Date(epoch * 1000);
        const now = new Date();
        const day = d => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        const days = Math.round((day(now) - day(date)) / 86400000);
        if (days === 0)
            return "Today";
        if (days === 1)
            return "Yesterday";
        if (days < 7)
            return Qt.formatDate(date, "dddd");
        if (date.getFullYear() === now.getFullYear())
            return Qt.formatDate(date, "ddd d MMM");
        return Qt.formatDate(date, "d MMM yyyy");
    }

    Process {
        id: snapshotReader

        command: ["backup-browse", "snapshots"]

        stdout: StdioCollector {
            id: snapshotOutput
        }

        onExited: exitCode => {
            let reply;
            try {
                reply = JSON.parse(snapshotOutput.text);
            } catch (e) {
                reply = {
                    error: exitCode === 0 ? "backup-browse returned nothing" : `backup-browse exited ${exitCode}`
                };
            }
            if (reply.error !== undefined) {
                root.snapshotsError = reply.error;
                root.snapshots = [];
                return;
            }
            root.snapshotsError = "";
            root.archive = reply.root;
            root.snapshots = reply.snapshots;
        }
    }

    Process {
        id: lister

        property bool stale: false

        stdout: StdioCollector {
            id: listOutput
        }

        onExited: exitCode => {
            if (lister.stale) {
                root.list();
                return;
            }
            let reply;
            try {
                reply = JSON.parse(listOutput.text);
            } catch (e) {
                reply = {
                    error: exitCode === 0 ? "backup-browse returned nothing" : `backup-browse exited ${exitCode}`
                };
            }
            // Switching snapshot keeps the path, and an older snapshot may
            // not have it yet: fall back to the nearest directory that exists.
            if (reply.missing && root.path !== "") {
                root.up();
                return;
            }
            if (reply.error !== undefined) {
                root.listError = reply.error;
                root.entries = [];
                root.previous = null;
                return;
            }
            root.listError = "";
            root.previous = reply.previous;
            root.entries = reply.entries;
        }
    }

    Process {
        id: restorer

        property string entryName: ""

        stdout: StdioCollector {
            id: restoreOutput
        }

        onExited: exitCode => {
            let reply;
            try {
                reply = JSON.parse(restoreOutput.text);
            } catch (e) {
                reply = {
                    error: `backup-browse exited ${exitCode}`
                };
            }
            if (reply.error !== undefined) {
                root.noticeIsError = true;
                root.notice = `Could not restore ${restorer.entryName}: ${reply.error}`;
                return;
            }
            root.noticeIsError = false;
            root.notice = `Restored to ${reply.dest}`;
            root.restored(reply.dest);
            // Re-read for the atHome flags; list() leaves the notice alone.
            root.list();
        }
    }
}
