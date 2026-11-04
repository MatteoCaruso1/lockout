# Session handoff (newest first, prepend only)

## 2026-11-03 22:23 ET: installed on the iPhone

- `npm run phone:install` succeeded: Lockout 0.1.0 (8) is on the phone (`apps query fun.thedailygame.lockout` confirms).
- Developer Mode still reports OFF (`amfi developer-mode-status` = false), so iOS will refuse to open the app until Matteo turns it on (Settings → Privacy & Security → Developer Mode → On → Restart → Turn On). It can't be switched on from the PC because the phone has a passcode.
- **Next:** once it's on, open Lockout and run docs/TEST-CHECKLIST.md section A (onboarding + 2-minute test lock), then fill LOOPHOLES.md "On device".

## 2026-11-03 18:25 ET: first installable build ready, waiting on the phone

- `ios-dev-0.1.0-b3` (Codemagic build 6aea6af1278b7d31e9043ac4) green: tests, dev signing for 3 IDs, .ipa, check-ipa ("3 targets entitled, no networking, Release build clean").
- b1/b2 failed at signing: Codemagic's variable field is single-line, so the pasted key lost its newlines (b1), and the value turned out to have no BEGIN/END lines (b2). `scripts/cert-key.sh` now rebuilds the PEM from either form and logs only its shape. Don't revert it.
- `C:\Users\matte\Downloads\Lockout.ipa` downloaded and inspected: v0.1.0 build 8, profile "Lockout ios_app_development" includes the iPhone UDID, family-controls + app group on all three, expires 2027-11-03.
- Entitlement: Matteo pressed Get Entitlement (2026-11-03). Watch email for Apple's reply.
- Developer Mode is OFF on the phone; the toggle was revealed with `npm run phone:devmode`.
- **Next (needs the phone plugged in):** Settings → Privacy & Security → Developer Mode → On → restart → Turn On. Then `npm run phone:install` (picks the newest .ipa in Downloads), open Lockout, and run docs/TEST-CHECKLIST.md section A.

## 2026-11-03 night: Apple portal done

- Registered device "Matteo iPhone 15 Pro" (iPhone16,1, iOS 26.7.1, UDID 00008130-000228A93A3A001C).
- App Group `group.fun.thedailygame.lockout`; App IDs `fun.thedailygame.lockout` (AK642DC733), `.monitor` (7F7R38Q7FK), `.shield` (5SQCP4HK33), each verified with Family Controls (Development) + App Groups (1 group assigned). In-App Purchase is on by default; harmless.
- Signing key: the `.p8` in Downloads\Codemagic key is the App Store Connect API key (already in Codemagic), NOT the certificate key. Generated a new RSA key `Downloads\Codemagic key\lockout_certificate_private_key` (not in repo); Matteo pastes it into Codemagic (form pre-filled: CERTIFICATE_PRIVATE_KEY, group appstore_credentials, Secret). It will mint a new Apple Development certificate on first dev build.
- Entitlement form: one "Get Entitlement" button that accepts terms; left for Matteo.
- **Next once the secret is in:** `npm run ship` in C:\dev\lockout → wait for `lockout-dev` → download .ipa → `npm run phone:devmode` (first time) → `npm run phone:install`.

## 2026-11-03 evening: repo live, first Codemagic check green

- GitHub: private `MatteoCaruso1/lockout`, main pushed.
- Codemagic: app `lockout` (id 6aea5b7db309907188297ad3, personal account; the Apple key from 100DG is connected at account level). Build #1 `lockout-check`: **26/26 unit tests pass, all three targets compile** (first try).
- Webhook created via "Update webhook" (needed so `npm run ship` tags start builds); this push tests it.
- Waiting on Matteo: (a) Apple developer sign-in (tab left open), (b) paste CERTIFICATE_PRIVATE_KEY into the prepared Codemagic form (lockout app → Environment variables, group appstore_credentials, Secret ticked), (c) plug in iPhone + Trust for `npm run phone:udid`.

## 2026-11-03 (later): blocked on browser access

**State:** 2 local commits on `main` (30b35d2, ed9163d). **No GitHub remote yet; nothing pushed.** Code never compiled (no Mac).
**Why stopped:** Claude in Chrome was not connected (3 tries), and creating the GitHub repo through the API with git's stored token was refused by the permission classifier. Every remaining setup step needs a signed-in browser.
**Tools ready:** `.venv-device/` has pymobiledevice3 installed; `usbmux list` found no phone (none plugged in).

**Next, in order:**
1. Create the private repo `MatteoCaruso1/lockout` (github.com/new, empty, no README), then `git remote add origin https://github.com/MatteoCaruso1/lockout.git && git push -u origin main`.
2. developer.apple.com → Identifiers: App Group `group.fun.thedailygame.lockout`; App IDs `fun.thedailygame.lockout`, `.monitor`, `.shield`, each with **Family Controls** + **App Groups** (assign the group).
3. Plug in the iPhone, `npm run phone:udid`, register that UDID under Devices.
4. Codemagic → add app from GitHub `lockout`; app env vars: group `appstore_credentials`, `CERTIFICATE_PRIVATE_KEY` (same value as the 100 Daily Games app; copy from its settings, or generate a new RSA key with `ssh-keygen -t rsa -b 2048 -m PEM`).
5. The push from step 1 triggers `lockout-check`; fix compile errors until green.
6. `npm run ship`, download the .ipa, `npm run phone:devmode` (first time), `npm run phone:install`.
7. Submit the docs/FAMILY-CONTROLS-REQUEST.md form; then work through docs/TEST-CHECKLIST.md and fill LOOPHOLES.md "On device".

## 2026-11-03: project created (stage 0 + code for stages 2–5)

**Goal (Matteo's words):** "an iPhone app that locks me out of nearly everything for a set period, and once a lock starts I cannot end it early. Only time ends it." Plan approved with defaults: 12h max lock (24h with extends), passcode shown 24h after asking and never during a lock, Apple ID recovery skipped, Downtime back-up layer, app removal blocked while schedules exist, bundle `fun.thedailygame.lockout` on team RAPMF3U34U, no Mac (Codemagic + USB install).

**Done:** all source written, never compiled yet (no Mac; the first Codemagic `lockout-check` run is the first compile). LockoutCore rules + tests, Shared enforcer, app screens, monitor + shield extensions, XcodeGen spec, codemagic.yaml (check / dev / testflight), ship + phone scripts, docs (loopholes, test checklist, entitlement request).

**Next:** see the newest section above this one once written; if none, (1) GitHub repo + push, (2) Apple portal: 3 bundle IDs with Family Controls + App Group, register the iPhone UDID, (3) Codemagic app + `appstore_credentials`, (4) fix compile errors from `lockout-check`, (5) `npm run ship`, install with `npm run phone:install`.
