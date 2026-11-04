# Lockout: test checklist for your iPhone

Do these in order. Each test begins with a short lock, so a mistake never costs more than a few minutes. Tick each box and write down anything odd; I fill the results into `LOOPHOLES.md`.

**Before you start:** the newest build is installed (see README "Install on your iPhone"), and you have about 45 minutes. Keep a second device nearby only to read this list.

## A. Setup (onboarding)
- [x] A1. Open Lockout. "Allow access" brings up Apple's Screen Time prompt; confirm with Face ID.
- [x] A2. "Choose Lockout": search for Lockout, tick it, tap Done.
- [x] A3. Remove every app except Phone from Always Allowed, as the app shows (anything left there is never blocked).
- [x] A4. (Optional) Set Downtime to your usual nightly window.
- [x] A5. Set the passcode Lockout shows. **Tap Cancel when iOS asks for an Apple ID.** If you did Downtime, switch on Block at Downtime. Tap "Seal it".
- [x] A6. Start the 2-minute test lock. During it, try: Safari, Messages, Instagram (or any app), App Store, Settings. Write down which ones opened.
- [x] A7. After 2 minutes, without touching Lockout, check that apps open again by themselves (the release comes from the extension, not the app).
- [x] A8. Back in Lockout, answer "Yes, everything was blocked" (Settings should have opened, Apple doesn't allow blocking it).

## B. Core lock
- [ ] B1. Custom lock of 15 minutes. The arming screen says "You cannot end this early". Tap the button, then **Cancel** during the countdown: no lock starts.
- [ ] B2. Custom 15 minutes again, let the countdown finish. Lockout now shows only the countdown and Extend. Try to find any way to settings, schedules or a stop button: there must be none.
- [ ] B3. Open a blocked app: the shield says "Locked until <time>" with one OK button that just closes the app.
- [ ] B4. Extend by 15 minutes; the end time moves later.
- [ ] B5. Long-press Lockout's icon on the Home Screen: "Remove App" must fail or be missing. Try deleting any other app too (also blocked).
- [ ] B6. Restart the phone mid-lock. After unlocking, apps are still blocked and the countdown carries on.
- [ ] B7. Force-quit Lockout (swipe it away). Apps are still blocked.
- [ ] B8. Turn on Low Power Mode. Still blocked.
- [ ] B9. Leave the phone untouched until the lock ends. Without opening Lockout, apps open again within about 5 minutes of the end time.

## C. Loopholes (one short lock each, 15 minutes)
- [ ] C1. **Clock:** Settings → General → Date & Time. Can you turn off "Set Automatically"? If yes, move the clock 2 hours ahead. Are apps still blocked? Open Lockout: does the countdown still show the real time left? (History shows a "clock" entry.)
- [ ] C2. **Revoke:** Settings → Screen Time → the list of apps with Screen Time access → Lockout → switch it off. What did it ask for (Face ID, phone passcode, Screen Time passcode)? Did apps unlock straight away? Open Lockout: it should send you back to "Allow access" and show the revoke in History. Re-authorize afterwards.
- [ ] C3. **Turn off Screen Time** completely: it should ask for the Screen Time passcode. Cancel.
- [ ] C4. **Siri:** "Hey Siri, text <someone> hello". Did it send?
- [ ] C5. **Notification reply:** have someone text you, then long-press the banner and reply. Did it send?
- [ ] C6. **Spotlight:** swipe down, search an app name and tap it (shielded?), then a web result (blocked?).
- [ ] C7. **Widgets / Control Center / lock-screen camera:** what works?
- [ ] C8. **iCloud sign-out:** Settings → your name → Sign Out. Is it greyed out?
- [ ] C9. **Share sheet / in-app browser:** in Lockout there's nothing to share; skip unless you find another route.
- [ ] C10. **Emergency call:** don't call 911. Just check the Emergency SOS slider is still on the power-off screen.

## D. Schedules and the 24-hour rule
- [ ] D1. Add a one-time schedule starting in about 20 minutes, 15 minutes long. Save: "applies now".
- [ ] D2. Try to delete it: the app says the change waits 24 hours. The schedule still shows under "Waiting out the 24h cooldown".
- [ ] D3. When it starts, apps lock without you opening Lockout; it releases by itself when it ends.
- [ ] D4. Add a repeating schedule (e.g. tonight). Make it longer: applies now. Make it shorter: waits 24h. Cancel the waiting change.
- [ ] D5. During any lock, Lockout shows only the countdown (no schedule editing).

## E. Passcode
- [ ] E1. Passcode screen → "Ask to see it". It says it will show 24 hours from now.
- [ ] E2. (Next day) It shows the code when no lock is running. Tap "Seal it again".
