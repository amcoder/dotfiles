pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// The MPRIS players on the bus and which one the transport keys act on,
// replacing playerctl.
//
// `Mpris.players` starts empty and fills in asynchronously, exactly as
// `DesktopEntries` and `Networking` do, so every value here is a binding and
// the bar item is what warms the singleton at startup.
//
// A binding over `players.values` re-evaluates only when a player appears or
// disappears, never when one of them starts playing or changes track, so the
// list below is rebuilt by hand from an Instantiator that watches each player
// individually. Its model is the model rather than `values`, so a watcher is
// created once per player and survives every state change.
Singleton {
    id: root

    // Players worth showing. Chrome keeps a stopped, untitled, uncontrollable
    // instance on the bus whenever it is running, and kdeconnect mirrors one
    // per remote app whether or not that app has any media -- neither is
    // something a transport key should ever land on.
    property var players: []

    // The last player known to be playing, or the one picked in the panel.
    // Recorded on the transition rather than derived, so pausing everything
    // leaves the transport keys pointed at what was last playing instead of
    // falling through to whichever mirror sorts first.
    property string activeName: ""

    property int revision: 0

    readonly property MprisPlayer active: {
        root.revision;

        const list = root.players;
        if (list.length === 0)
            return null;

        return list.find(player => player.dbusName === root.activeName) ?? list.find(player => player.isPlaying) ?? list[0];
    }

    readonly property bool available: root.active !== null
    readonly property bool playing: root.active?.isPlaying ?? false

    readonly property string title: root.active?.trackTitle ?? ""
    readonly property string artist: root.active?.trackArtist ?? ""

    // What the bar shows: the track, qualified by artist where there is one.
    readonly property string label: {
        if (root.title === "")
            return root.active?.identity ?? "";
        if (root.artist === "")
            return root.title;
        return `${root.artist} — ${root.title}`;
    }

    function usable(player: MprisPlayer): bool {
        return player.canControl && (player.canTogglePlaying || player.trackTitle !== "");
    }

    // Assigns only when the set actually changes, so a title change does not
    // hand every list bound to `players` a fresh array and rebuild its rows.
    function refresh(): void {
        const next = Mpris.players.values.filter(root.usable);
        if (next.length === root.players.length && next.every((player, i) => player === root.players[i]))
            return;

        root.players = next;
    }

    function select(player: MprisPlayer): void {
        root.activeName = player.dbusName;
    }

    function playPause(): void {
        if (root.active?.canTogglePlaying)
            root.active.togglePlaying();
    }

    function next(): void {
        if (root.active?.canGoNext)
            root.active.next();
    }

    function previous(): void {
        if (root.active?.canGoPrevious)
            root.active.previous();
    }

    function seek(fraction: real): void {
        const player = root.active;
        if (!player?.canSeek || !player.lengthSupported || player.length <= 0)
            return;

        player.position = fraction * player.length;
    }

    Instantiator {
        model: Mpris.players

        onObjectAdded: root.refresh()
        onObjectRemoved: root.refresh()

        delegate: QtObject {
            id: watcher

            required property MprisPlayer modelData

            readonly property Connections player: Connections {
                target: watcher.modelData

                function onIsPlayingChanged(): void {
                    if (watcher.modelData.isPlaying)
                        root.activeName = watcher.modelData.dbusName;
                    root.revision++;
                    root.refresh();
                }

                function onTrackTitleChanged(): void {
                    root.revision++;
                    root.refresh();
                }

                function onCanTogglePlayingChanged(): void {
                    root.refresh();
                }
            }

            // A player already playing when it appears emits no transition, so
            // without this the first Spotify track of a session leaves
            // `activeName` empty and a kdeconnect mirror wins the fallback.
            Component.onCompleted: {
                if (watcher.modelData.isPlaying)
                    root.activeName = watcher.modelData.dbusName;
            }
        }
    }

    IpcHandler {
        target: "media"

        function playPause(): void {
            root.playPause();
        }

        function next(): void {
            root.next();
        }

        function previous(): void {
            root.previous();
        }
    }
}
