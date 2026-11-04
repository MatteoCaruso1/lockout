# Lockout loophole report

Status key: **Closed** = cannot be done during a lock. **Mitigated** = can be done, but it is slowed down, partial, or logged. **Open** = works, and Lockout cannot stop it.
"Expected" is the status from research and the code. "On device" gets filled in after the test on your iPhone (`docs/TEST-CHECKLIST.md` section C). Until a row has an on-device result, treat it as unproven.

| # | Loophole | Expected | On device | How Lockout handles it |
|---|---|---|---|---|
| 1 | Switch off Lockout's Screen Time access (Settings → Screen Time → apps with access) | **Open** | not tested yet | Developers report it asks only for Face ID / phone passcode, not the Screen Time passcode, on iOS 16 to 18.5 ([forum](https://developer.apple.com/forums/thread/714651)). Switching it off releases every shield at once. Lockout logs it the next time it opens and makes you re-authorize. Back-up layer: iOS Downtime with "Block at Downtime", protected by the sealed passcode, covers your nightly window anyway. On-demand locks have no back-up. |
| 2 | Turn Screen Time off entirely | **Closed** (with sealed passcode) | not tested yet | Needs the Screen Time passcode, which Lockout keeps sealed. |
| 3 | Reset the Screen Time passcode with your Apple ID ("Forgot passcode?") | **Closed** if you tapped Cancel at the recovery prompt | not tested yet | Onboarding makes you confirm you skipped Apple ID recovery. Without recovery the only reset is erasing the phone. |
| 4 | Change the clock to end a lock early | **Closed or mitigated** | not tested yet | (a) During a lock Lockout sets "require automatic date & time", which may grey out the switch. (b) Even if the clock does change, Lockout measures real time with a clock that can't be changed (time since boot), keeps the lock running, and schedules a new end. Gap: a restart combined with a clock change falls back to the wall clock. |
| 5 | Restart the phone | **Closed** | not tested yet | Shields and schedules are stored by iOS and survive restarts. |
| 6 | Force-quit Lockout | **Closed** | not tested yet | Nothing depends on the app running; the monitor extension does all lock and release work. |
| 7 | Low Power Mode | **Closed** (expected) | not tested yet | No effect on Screen Time shields. |
| 8 | iOS update mid-lock | **Closed** (expected) | not tested yet | Updating restarts the phone, same as #5. Hard to test on purpose. |
| 9 | Delete Lockout | **Closed** | not tested yet | "Deny app removal" is on during every lock, and also between locks while any schedule exists (deleting a schedule waits 24h, so the protection does too). Side effect: you can't delete any app then. |
| 10 | Delete and reinstall | **Closed** | not tested yet | Same as #9: deletion is blocked. |
| 11 | Sign out of iCloud / Apple ID | **Mitigated** | not tested yet | "Lock accounts" during locks, plus the Screen Time passcode. May only be honoured for child accounts; to verify. |
| 12 | Siri sends a text | **Closed or open** | not tested yet | Lockout sets "deny Siri" during locks. If iOS ignores it for personal authorization, Siri can still send texts. |
| 13 | Reply from a notification (Messages banner) | **Open** (expected) | not tested yet | Shields block opening apps, not notification quick-replies. Mitigation you can do: Settings → Notifications → Messages → turn off "Show Previews" or the notifications. |
| 14 | Spotlight search | **Mitigated** (expected) | not tested yet | You can search, but opening any result opens a shielded app. Web results open Safari, which is blocked. |
| 15 | Widgets on Home / Lock Screen | **Open** (expected) | not tested yet | Widgets show content (news, weather) without opening the app. Tapping one opens the shielded app. |
| 16 | Control Center | **Open** (expected) | not tested yet | Flashlight, calculator, timer and similar work. Apps it opens are shielded. |
| 17 | Lock-screen camera | **Open** (expected) | not tested yet | The lock-screen camera is a separate system feature; the shield doesn't cover it. Opening Photos from it is shielded. |
| 18 | App Library | **Closed** | not tested yet | Every app it opens is shielded. |
| 19 | Share sheets | **Mitigated** (expected) | not tested yet | Share extensions from other apps may still appear inside an allowed app. Lockout is the only allowed app and has no share button. |
| 20 | In-app browsers | **Closed** (expected) | not tested yet | All web content is blocked system-wide, which covers web views inside apps. Every app is shielded anyway. |
| 21 | Phone app / emergency calls | **Open, by design** | not tested yet | Apple never lets apps block calls. You asked for calls to work. |
| 22 | Settings app | **Open, by design** | not tested yet | Apple doesn't allow shielding Settings. That is why #1 matters. |
| 23 | Use another device (iPad, Mac, laptop) | **Open** | n/a | Lockout only locks this iPhone. |
| 24 | Apps on iOS's Always Allowed list | **Mitigated** (setup step 3) | **Closed (2026-11-04).** First 2-minute test: 100 Daily Games, Messenger, Maps, Calendar, Weather, Sportsnet and Partiful got through (they were on Always Allowed). After removing them, a 15-minute lock blocked all 7, and the lock ended by itself on time | iOS never blocks an Always Allowed app, and no app can override that ([forum](https://developer.apple.com/forums/thread/724419)). Setup now has you remove every app except Phone. Adding an app back needs the sealed Screen Time passcode, so once the list is empty it stays empty. |

## The bottom line, plainly
Lockout makes ending a lock early slow, deliberate and logged. It cannot make it impossible. One move, switching off its Screen Time access in Settings with Face ID, ends a lock straight away, and Apple gives apps no way to block that. Downtime with a sealed passcode is the one layer that survives it, and only for your recurring window.
