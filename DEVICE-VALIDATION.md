# Phase 5 — Physical iPhone validation

Status: pending. No physical device was available during the September 6, 2026 continuation. Simulator tests do not satisfy this gate.

Complete three real, manually built workouts to validate the execution layer. The user authorized JSON import development in parallel on September 26; this device gate remains pending. Use your normal training loads and exercises. Record device model, iOS version, build, date, and any friction for each session. Compare exact results in History after each workout; any lost or duplicated completed set fails the gate.

| Session | Checks during the workout | Result |
|---|---|---|
| 1 — Normal use | Build offline using the saved unit. Edit the first load, add a set, and start. Log with one thumb without opening the keyboard. Lock during rest; check the notification and next-set context after unlocking. Finish with a note and compare History and the coach update with actual work. | Pending |
| 2 — Interruptions | Keep networking off. Log a set, extend rest, then force-quit and relaunch. Verify the exact completed set and remaining rest. Repeat after rest has expired. Pause/resume, finish, and verify duration excludes paused time. | Pending |
| 3 — Corrections and reach | Undo an accidental completion. Edit a completed result, adjust pending sets, add and remove pending work, and cancel an unfinished-workout confirmation. Check large text, VoiceOver, and primary-control reach. Finish and verify planned-versus-actual data and verbatim notes. | Pending |

For the expanded local tracker, include a superset or circuit, replace a movement after logging its first set, and verify both movement identities in History. Pause during rest, lock the phone beyond the original deadline, then resume and verify that the remaining rest was frozen. Try both gym appearances, a notification preference change, and a JSON/CSV share to a destination you choose. Use disposable test workouts for deletion checks.

Also choose a later unfinished set from Workout overview, relaunch before logging, and verify the original order resumes afterward. Log actual RPE/RIR and a set note, edit them after completion, and compare History and the coach share. Add an optional actual load/duration and check that it retains its unit. Check the twelve-week day filter and exact exercise volume after finishing.

Also import the confirmed Lower A JSON via Files, inspect custom-name review and stop instructions, start offline, and compare exact targets and exported source after completion. Change notification permission in iPhone Settings during rest, return, and check reconciliation without an unsolicited prompt.

Across these sessions, check bright lighting and music playback. Record notification permission state. Check a timezone change during rest; test a manual wall-clock change separately and record any timer or elapsed-time discrepancy.

For each issue record the action, expected result, actual result, and whether relaunch preserved the data. Do not enter private workout details in shared diagnostics.

Exit: three completed real workouts, zero lost completed sets, and all blocking execution/recovery issues resolved. Update `PLAN.md` and `CONTINUATION.md` with actual results before marking the device gate complete.

## Share Extension host checks

On a signed iPhone build with the App Group enabled, share one JSON file from Files and workout text from Notes, ChatGPT, Claude, Gemini, Messages and email. Include Safari/conversation links with no workout text and verify the copy instructions. Cancel before Save and confirm nothing is queued; repeat Save for the same pending source and confirm one draft. Keep an existing import draft, share a different workout, and confirm it is preserved until explicit replacement. Open the app offline, review shared JSON, add it to Today, finish and verify exact exported source. Share during an active workout and confirm it does not interrupt logging. Delete all local workout data and confirm both the pending draft and shared inbox are cleared.

## Configured text conversion checks (after live evaluation)

Use a private build with HTTPS service/auth provisioned. Confirm the transmission explanation names what is sent, cancel once before sending and once while waiting, and verify the local text survives reopening without automatic retry. Test offline/budget/auth failure, multiple-workout selection, required ambiguity preventing acceptance, and exact original text/source link in export. Run provider accuracy evaluation before treating clear-source conversion as reliable. Existing JSON and already prepared workouts must still run offline.
