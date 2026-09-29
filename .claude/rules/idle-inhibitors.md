---
paths:
  - ".config/quickshell/services/IdleInhibitService.qml"
  - ".config/quickshell/modules/bar/IdleInhibit.qml"
  - ".config/quickshell/modules/idle/IdleInhibitPanel.qml"
---

# Idle inhibitors

**Idle inhibitors** (`services/IdleInhibitService.qml`,
`modules/bar/IdleInhibit.qml`, `modules/idle/IdleInhibitPanel.qml`): a coffee
cup left of the clock, shown only while something is holding the session awake,
whose popup names what. Two mechanisms answer that question and both are listed
— a Wayland `zwp_idle_inhibitor_v1` on a window, and a logind idle inhibitor on
a process — and **both now really do hold idle off**, since swayidle honours
each (see Quickshell, above). Insomnia's third mode appears in the logind half,
since that is how it takes its lock. This indicator is load-bearing rather than
informational: it is what makes the deliberate absence of any ceiling on
inhibitor-held idle acceptable.

**An inhibitor existing is not the same as it holding idle off**, and the icon
follows sway's own rule rather than the object's presence. Sway reports
`idle_inhibitors: {application, user}` per container in `get_tree`, and an
`application` inhibitor counts only while that view is `visible`; each
`inhibit_idle` mode has a test of its own (`open` always, `visible`/`fullscreen`
on visibility, `focus` on the view or a child being focused), which is why the
config's `for_window [con_mark="no idle"] inhibit_idle open` is picked up.
Verified as a mirror-image A/B: with Chrome and Claude visible and both holding
an `application` inhibitor the cup shows, and with the same two inhibitor
_objects_ still reported on a hidden workspace and no logind inhibitor it is
gone, the rest of the bar unmoved in both. Sway's attribution of an inhibitor to
a particular view has been seen to be misleading, so a _row_ may name the wrong
window even though the aggregate is right.

Neither side has a change signal, so it polls at 5s: sway emits no IPC event
when a client takes or drops an inhibitor, and logind's `BlockInhibited` says
only whether _something_ holds idle, not what. Both reads cost ~7ms. The logind
half is `busctl --json=short call … ListInhibitors`, whose rows are
`[what, who, why, mode, uid, pid]`; **logind refuses a delay-mode idle
inhibitor** ("Delay inhibitors only supported for shutdown and sleep"), so every
row naming idle is a block and there is no mode to filter on.

Two naming traps. `children` is a **read-only property on every QML object**, so
a singleton defining `function children(...)` fails to load with "Invalid
property assignment" and takes the whole shell down with it — the tree walk is
`childNodes`. And the bar item is `IdleInhibit`, not `IdleInhibitor`, because
`Bar.qml` instantiates Quickshell's own `IdleInhibitor` type and a
same-directory component of that name would shadow it.
