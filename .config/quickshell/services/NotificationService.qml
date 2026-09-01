pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The session's notification daemon. Owns the freedesktop server, the popup
// queue and the history ring buffer persisted to Quickshell.stateDir.
Singleton {
    id: root

    readonly property int historyLimit: 100
    readonly property int saveDelay: 1000

    // Fallbacks for `expire_timeout = -1`, in milliseconds. 0 never expires.
    readonly property var defaultTimeouts: [5000, 10000, 0]

    property bool dnd: false
    property bool centreVisible: false
    property int unread: 0

    // Records of what is on screen, newest first.
    property var popups: []

    // Records, newest first. `notification` is null for anything restored from
    // disk or closed by its sender, and such a record has no working actions.
    property var history: []

    property bool popupsHovered: false

    // Ticks while the centre is open, so relative timestamps stay current.
    property double now: Date.now()

    property int nextKey: 1

    // A live record carries no copy of the fields: fields() reads the notification
    // itself until forget() freezes it.
    function record(notification: var): var {
        return {
            key: root.nextKey++,
            time: Date.now(),
            expiresAt: 0,
            notification: notification
        };
    }

    // What to persist and what to draw when the notification is gone. The live
    // object is authoritative while it exists, because a client replacing a
    // notification by id mutates it in place rather than sending a new one.
    function fields(entry: var): var {
        const notification = entry.notification;

        if (!notification)
            return {
                id: entry.id,
                appName: entry.appName,
                appIcon: entry.appIcon,
                image: entry.image,
                summary: entry.summary,
                body: entry.body,
                urgency: entry.urgency,
                progress: entry.progress
            };

        return {
            id: notification.id,
            appName: notification.appName,
            appIcon: notification.appIcon,
            image: notification.image,
            summary: notification.summary,
            body: notification.body,
            urgency: notification.urgency,
            progress: notification.hints.value === undefined ? -1 : Math.round(notification.hints.value)
        };
    }

    function popupDuration(notification: var): int {
        if (notification.expireTimeout >= 0)
            return notification.expireTimeout;
        return root.defaultTimeouts[notification.urgency] ?? 10000;
    }

    function add(notification: var): void {
        notification.tracked = true;
        notification.closed.connect(() => root.forget(notification));
        notification.summaryChanged.connect(() => root.refresh(notification));
        notification.bodyChanged.connect(() => root.refresh(notification));

        const entry = root.record(notification);

        if (!notification.transient) {
            root.history = [entry].concat(root.history.slice(0, root.historyLimit - 1));
            if (!root.centreVisible)
                root.unread += 1;
            root.scheduleSave();
        }

        if (!root.dnd) {
            const duration = root.popupDuration(notification);
            entry.expiresAt = duration === 0 ? 0 : entry.time + duration;
            root.popups = [entry].concat(root.popups);
        }
    }

    // A replaced notification pops again and moves back to the top of history.
    function refresh(notification: var): void {
        const entry = root.history.find(other => other.notification === notification) ?? root.popups.find(other => other.notification === notification);

        if (!entry)
            return;

        entry.time = Date.now();

        if (root.history.indexOf(entry) > 0)
            root.history = [entry].concat(root.history.filter(other => other !== entry));

        root.scheduleSave();

        if (root.dnd)
            return;

        const duration = root.popupDuration(notification);
        entry.expiresAt = duration === 0 ? 0 : entry.time + duration;

        if (!root.popups.includes(entry))
            root.popups = [entry].concat(root.popups);
    }

    // The sender (or we) closed it: drop the popup and let the history entry go
    // inert -- keeping its last values -- rather than removing it, which is what
    // dunst's history did.
    function forget(notification: var): void {
        root.popups = root.popups.filter(entry => entry.notification !== notification);
        root.history = root.history.map(entry => entry.notification === notification ? Object.assign({}, entry, root.fields(entry), {
            notification: null
        }) : entry);
        root.scheduleSave();
    }

    function hidePopup(key: int): void {
        root.popups = root.popups.filter(entry => entry.key !== key);
    }

    function hideAllPopups(): void {
        root.popups = [];
    }

    function defaultAction(entry: var): var {
        if (!entry || !entry.notification)
            return null;
        return entry.notification.actions.find(action => action.identifier === "default") ?? null;
    }

    // Invoking an action closes the notification unless it asked to stay.
    function invoke(entry: var, action: var): void {
        if (!entry || !entry.notification || !action)
            return;

        action.invoke();

        if (!entry.notification.resident)
            entry.notification.dismiss();
        else
            root.hidePopup(entry.key);
    }

    function activate(entry: var): void {
        const action = root.defaultAction(entry);
        if (action)
            root.invoke(entry, action);
        else
            root.dismiss(entry);
    }

    function dismiss(entry: var): void {
        if (!entry)
            return;

        root.hidePopup(entry.key);

        if (entry.notification)
            entry.notification.dismiss();
    }

    function discard(entry: var): void {
        root.dismiss(entry);
        root.history = root.history.filter(other => other.key !== entry.key);
        root.scheduleSave();
    }

    function clearHistory(): void {
        for (const entry of root.history) {
            if (entry.notification)
                entry.notification.dismiss();
        }

        root.history = [];
        root.popups = [];
        root.unread = 0;
        root.scheduleSave();
    }

    function showCentre(): void {
        root.now = Date.now();
        root.centreVisible = true;
        root.unread = 0;
    }

    function hideCentre(): void {
        root.centreVisible = false;
    }

    function toggleCentre(): void {
        if (root.centreVisible)
            root.hideCentre();
        else
            root.showCentre();
    }

    function toggleDnd(): void {
        root.dnd = !root.dnd;

        if (root.dnd)
            root.hideAllPopups();

        root.scheduleSave();
    }

    function scheduleSave(): void {
        saveTimer.restart();
    }

    function save(): void {
        store.setText(JSON.stringify({
            dnd: root.dnd,
            notifications: root.history.map(entry => Object.assign(root.fields(entry), {
                time: entry.time
            }))
        }));
    }

    function restore(text: string): void {
        const state = JSON.parse(text);
        const stored = state.notifications ?? [];

        root.dnd = state.dnd === true;

        root.history = stored.slice(0, root.historyLimit).map(entry => Object.assign({}, entry, {
            key: root.nextKey++,
            expiresAt: 0,
            notification: null
        }));
    }

    NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true
        inlineReplySupported: false
        keepOnReload: false

        onNotification: notification => root.add(notification)
    }

    // Popup lifetimes are polled rather than timed per card, because the popup
    // list is a plain array and a Repeater rebuilds every delegate when it changes.
    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0

        onTriggered: {
            if (root.popupsHovered)
                return;

            const now = Date.now();
            const live = root.popups.filter(entry => entry.expiresAt === 0 || entry.expiresAt > now);

            if (live.length !== root.popups.length)
                root.popups = live;
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.centreVisible

        onTriggered: root.now = Date.now()
    }

    Timer {
        id: saveTimer

        interval: root.saveDelay

        onTriggered: root.save()
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.toggleCentre();
        }

        // Not show()/hide(): `quickshell ipc call <target> show` is swallowed by
        // the CLI's own `ipc show` subcommand.
        function open(): void {
            root.showCentre();
        }

        function close(): void {
            root.hideCentre();
        }

        function dnd(): void {
            root.toggleDnd();
        }

        function invoke(): void {
            root.activate(root.popups[0] ?? root.history[0]);
        }

        function dismiss(): void {
            root.dismiss(root.popups[0]);
        }

        function clear(): void {
            root.clearHistory();
        }
    }

    FileView {
        id: store

        path: Quickshell.statePath("notifications.json")
        preload: true
        printErrors: false

        onLoaded: {
            try {
                root.restore(store.text());
            } catch (error) {
                root.history = [];
            }
        }
    }
}
