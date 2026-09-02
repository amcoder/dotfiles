import qs.services
import qs.windows

// The countdown a destructive session action goes through. Instantiated once
// for the session rather than per bar, unlike the menu it follows: it is a
// modal on the focused output, and the action it announces is not tied to the
// bar the menu was opened from.
CountdownDialog {
    visible: PowerService.pending !== null

    title: PowerService.pending ? PowerService.pending.label : ""
    acceptText: PowerService.pending ? PowerService.pending.label : ""
    countdown: PowerService.confirmSeconds

    onAccepted: PowerService.confirm()
    onRejected: PowerService.cancel()
}
