# Lockout

A strict iPhone lock app for one person on one phone. You start a lock (or a schedule starts it) and every app and website is blocked until the time is up. Nothing in the app can end it early. No accounts, no network, no backend.

## How it works, in one paragraph
Apple's Screen Time APIs do the blocking. The app writes your locks and schedules to a small file shared with two extensions. The **monitor extension** is started by iOS itself when a lock or schedule begins or ends. Whatever the event, it re-reads the file and works out whether a lock should be running right now, then blocks or releases. Because every release goes through that one calculation, a lock ends on time even if the app is never opened again, and a backup event 5 minutes later repeats the check in case the first one is missed. The **shield extension** draws the "Locked until 7:00 PM" screen.

## Layout
| Path | What |
|---|---|
| `LockoutCore/` | All the rules (lock lengths, 24h cooldown, clock-tamper check, passcode wait) as plain Swift with unit tests |
| `Shared/` | Saved-state file, the device clock, and `Enforcer` (the one place that turns state into Screen Time settings) |
| `App/` | SwiftUI screens: onboarding, lock presets, arming, countdown, schedules, passcode, history |
| `Monitor/` | DeviceActivityMonitor extension |
| `Shield/` | ShieldConfiguration extension |
| `project.yml` | XcodeGen spec; the Xcode project is generated on Codemagic |
| `codemagic.yaml` | Cloud builds (check on push, dev build / TestFlight on tags) |
| `docs/` | Loophole report, phone test checklist, Apple entitlement request |
| `handoff/` | Session handoff (prepend-only) |

## Ship a build
```
npm run ship
```
Pushes a tag. Codemagic runs the tests, builds a development-signed `.ipa`, and checks it (entitlements on all three targets, no networking, no debug unlock in Release builds). `npm run ship -- --debug` builds a Debug version with a red emergency-release button for testing.

## Install on your iPhone (Windows, USB)
1. Download the `.ipa` from the Codemagic build page (Artifacts).
2. Plug the iPhone in, unlock it, tap **Trust**.
3. `npm run phone:install` installs the newest `.ipa` in Downloads.
4. First time only: `npm run phone:devmode`, then on the phone Settings → Privacy & Security → **Developer Mode** → On, and restart.

A development build only installs on iPhones registered in the Apple Developer account (`npm run phone:udid` prints the ID to register). Development builds expire after about a year; just reinstall.

## Safety
- Every lock ends on its own: trusted end time, two scheduled release events, and a hard cap of 25 hours after it started, whatever the saved data says.
- If the saved data is ever damaged, Lockout reads it as "no lock" (fails open).
- The longest single lock is 12 hours; extending can reach 24 hours after the start.
- The emergency release exists only in Debug builds; the build fails if it is found in a Release build.
- Lockout never touches calls; emergency calls always work.
