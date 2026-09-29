---
paths:
  - ".local/bin/camera-watch"
  - ".config/quickshell/services/PrivacyService.qml"
  - ".config/quickshell/modules/bar/Privacy.qml"
  - ".config/quickshell/modules/privacy/**"
---

# Privacy indicators

**Privacy indicators** (`.local/bin/camera-watch`, `services/PrivacyService.qml`, `modules/bar/Privacy.qml`, `modules/privacy/PrivacyPanel.qml`): a webcam and a microphone icon in red, in the centre section left of the clock, shown only while something is capturing — so a camera or a mic that is live when nothing should be is visible rather than inferred. The two icons are **one** item with one `BarPopup` behind them, because they raise the same question and it has a single answer: the card names the processes holding each device, with the pid, which is what turns "something is listening" into something answerable. It is a report and not a control — stopping a capture belongs to the app doing it.

The two halves share nothing but the question. **The microphone is Pipewire's to report**, and the discriminator is the *link*, not the node: a capture is a `Stream/Input/Audio` node, and so is a desktop-audio capture — a screenshare with audio, `wf-recorder -a` — which is fed by the `Audio/Sink` where a microphone capture is fed by an `Audio/Source`. Measured both ways round: `pw-record` on the mic linked from the source, and `PIPEWIRE_PROPS='{ stream.capture.sink = true }' pw-record --target=<sink>` linked from the sink, on the same node type. A stream with no link at all is connected to nothing and is not use either, which is what keeps an idle stream dark for free. Node `type` and link ends are both readable **untracked**, so this needs no `PwObjectTracker` — and `properties` on an untracked node reads `{}` rather than empty strings, so nothing here can name the app.

**V4L2 exposes no in-use flag**, so the webcam half is which processes hold a `/dev/video*` node open. inotify `open`/`close` on the device nodes is the trigger — it works on devtmpfs, measured at 17ms from open to event — and `fuser` is the read, at 64ms. A shell loop over `/proc/*/fd` is not an alternative: measured at **15.2s**, and slow enough that it walks past a holder that has since closed, which is what a first pass mistook for the device not being held at all. The 250ms settle before each read is what keeps an app *enumerating* devices from flashing the indicator — measured, an open followed immediately by a close reports nothing at all, while a real hold is reported 340ms in and its release 320ms after. `fuser` sees only this user's processes, so a camera opened by a root process reads as idle.

The bar's centre grew a **Row** for it: everything hanging off the clock's left edge shares one, because `Recording` measures a non-zero width even while hidden (its elapsed time is still `0:00`), so two individually anchored indicators would each hold a gap open beside the clock. A positioner drops an invisible child entirely, spacing included. Verified byte-exact against `grim`: across idle, mic, camera and both, every column from the date rightward is identical and only the columns left of the clock change, growing outward.

Naming the microphone's user is the one thing here that costs a `PwObjectTracker`: an untracked node reports `properties` as `{}`, so `PrivacyService` tracks the streams its filter already selected and reads `application.name` and `application.process.id`, falling back to the node name. The camera's names come from `camera-watch`, which reports `idle` or `active` followed by one tab-separated `<command> (<pid>)` per holder; `/proc/<pid>/comm` is the command, so what appears is the process rather than the app — Chrome's webcam holder is its `VideoCaptureService` utility process, showing as `chrome`.

The watcher's outer loop is what makes it self-healing: kill its `inotifywait` and the pipe ends, the loop restarts it two seconds later and re-reports the state from scratch, which is why a repeat of the current state is expected on the wire and ignored by the reader. Verified by killing it under the running shell — the indicator lit and cleared again afterwards.

Phosphor's `video-camera` is vendored for this; `video` is a screen with a play triangle and `eye` is already the Insomnia indicator.

