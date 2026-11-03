# Family Controls (Distribution) entitlement request

**Why:** Without it, Lockout can only be installed as a development build, over USB, on iPhones registered to the account. TestFlight and the App Store both need Apple to approve "Family Controls (Distribution)" for **each** of the three bundle IDs. Approvals are reported to cover the main app only unless the extensions are named, so all three are listed.

**Where:** https://developer.apple.com/contact/request/family-controls-distribution (signed in as the account holder of team RAPMF3U34U). One request per bundle ID if the form asks for one at a time.

**Status:** not submitted yet (2026-11-03).

## Answers to paste

**App name:** Lockout

**Bundle IDs:**
- fun.thedailygame.lockout
- fun.thedailygame.lockout.monitor (DeviceActivityMonitor extension)
- fun.thedailygame.lockout.shield (ShieldConfiguration extension)

**Description of how the app uses Family Controls:**
> Lockout is a personal digital-wellbeing app. The device owner uses it to lock themselves out of distracting apps and websites for periods they choose: on demand (for example "lock me out for 3 hours") or on a recurring schedule (for example every night from 10 PM to 7 AM). It uses individual Screen Time authorization (AuthorizationCenter, .individual), so only the owner of the device can turn it on.
>
> FamilyControls: individual authorization, and FamilyActivityPicker so the user can exempt Lockout itself from the shield.
> ManagedSettings: during a lock, shields all application categories and web domains, blocks web content, and prevents app removal. Settings are cleared when the lock ends.
> DeviceActivity: schedules the start and end of every lock, so locks start and release on time even if the app is never opened. The DeviceActivityMonitor extension applies and clears the settings.
> ManagedSettingsUI: a ShieldConfiguration extension shows a custom message on the shield, such as "Locked until 7:00 PM".
>
> The app has no accounts, makes no network requests, and collects no data. Everything stays on the device. It does not monitor or control any other person or device.

**Is this app for parental controls / for children?** No. Personal self-control, individual authorization only.

**Will it be on the App Store?** Distribution to the developer's own devices through TestFlight first; App Store possibly later.
