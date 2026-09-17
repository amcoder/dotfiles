//@ pragma UseQApplication
import Quickshell
import qs.modules.backup

// The backup browser, a window over the snapshots on the NAS. Its own
// process rather than a surface in the shell, started by `backup-browser`:
//
//     quickshell -p ~/.config/quickshell/backups.qml
//
// Rooted at the shell's config directory so `import qs.*` resolves as it does
// for shell.qml, and so a theme switch reaches it through the same
// palette.json.
ShellRoot {
    BackupBrowser {}
}
