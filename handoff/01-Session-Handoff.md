# Session handoff (newest first, prepend only)

## 2026-11-03: project created (stage 0 + code for stages 2–5)

**Goal (Matteo's words):** "an iPhone app that locks me out of nearly everything for a set period, and once a lock starts I cannot end it early. Only time ends it." Plan approved with defaults: 12h max lock (24h with extends), passcode shown 24h after asking and never during a lock, Apple ID recovery skipped, Downtime back-up layer, app removal blocked while schedules exist, bundle `fun.thedailygame.lockout` on team RAPMF3U34U, no Mac (Codemagic + USB install).

**Done:** all source written, never compiled yet (no Mac; the first Codemagic `lockout-check` run is the first compile). LockoutCore rules + tests, Shared enforcer, app screens, monitor + shield extensions, XcodeGen spec, codemagic.yaml (check / dev / testflight), ship + phone scripts, docs (loopholes, test checklist, entitlement request).

**Next:** see the newest section above this one once written; if none, (1) GitHub repo + push, (2) Apple portal: 3 bundle IDs with Family Controls + App Group, register the iPhone UDID, (3) Codemagic app + `appstore_credentials`, (4) fix compile errors from `lockout-check`, (5) `npm run ship`, install with `npm run phone:install`.
