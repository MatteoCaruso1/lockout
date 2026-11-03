# Lockout: rules for every session

Read `handoff/01-Session-Handoff.md` first (newest section at the top), then `README.md`.

## Non-negotiables
- **Never brick the phone.** Every code path that could keep a shield on must have an end that does not depend on the main app: `LockInstance.isActive` hard cap, `MonitorPlan` backup activities, and fail-open reading in `StateStore`. Do not remove any of the three.
- **No override paths in Release.** No ShieldAction extension. No stop button. Anything for testing goes inside `#if DEBUG`, and `scripts/check-ipa.sh` must keep failing a Release build that contains `LOCKOUT_DEBUG_EMERGENCY_RELEASE`.
- **No network, no backend, no analytics.** `check-ipa.sh` fails the build on networking symbols.
- **All rules live in `LockoutCore` with tests.** Screens and extensions only call `Enforcer.refresh` and `AppState` methods.
- **Saved-state format:** new fields must decode with `decodeIfPresent` and a default (see `AppState.init(from:)`), or an update could make old data unreadable, which reads as "unlocked" and loses schedules.
- Never modify `C:\dev\the-daily-game`. It is only the template for the Codemagic setup.

## Handoff (same rule as 100 Daily Games)
End every session that changed anything by **prepending** a section to `handoff/01-Session-Handoff.md`: what changed, what is unverified, the exact next step. Never overwrite the file (no `>` redirect, no Write tool on it; use Edit at the top).

## Building
No Mac. Codemagic only: push to main runs `lockout-check`; `npm run ship` tags a dev build. Apple team RAPMF3U34U, Codemagic integration "TDG App Store Key", secret group `appstore_credentials` (CERTIFICATE_PRIVATE_KEY).
