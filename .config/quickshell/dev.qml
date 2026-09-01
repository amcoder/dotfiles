//@ pragma UseQApplication
import Quickshell

// A second entry point for working on one surface at a time:
//
//     quickshell -p ~/.dotfiles/.config/quickshell/dev.qml
//
// `-p` roots the config at this directory, so `import qs.*` resolves exactly as
// it does for shell.qml while running as a separate instance.
//
// Never instantiate the notification server, the polkit agent or SystemTray
// here: each claims a D-Bus name and would fight the running shell for it.
ShellRoot {}
