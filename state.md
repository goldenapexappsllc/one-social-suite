# 1Social — State

Drop this at `/Volumes/DevDrive/one_social_suite/STATE.md`.

Paste it at the top of the 1Social chat tab when starting a session, or let Claude Code pick it up from the repo. Update it at the end of a session by saying "update STATE."

Last updated: 2026-08-06

---

## What it is

Flutter cross-platform social posting app. Write once, share across 9 platforms using copy-and-open handoff. No API posting — the user taps through to each app themselves. That is deliberate and it is the privacy story.

- Project: `/Volumes/DevDrive/one_social_suite`
- Name is **1Social**. Final. "1PrivateSocial" and "OnePrivateSocial" are parked — do not raise them.
- Android package: `com.goldenapexapps.onesocial`
- Owner: GoldenApexApps LLC
- Contact: info@goldenapexapps.com / www.goldenapexapps.com

## Where I am right now

Rebuilding from the known-good DevDrive backup. The previously staged signed build got removed after it broke on the OpenAI key switch, so I went back to the backup and I am working forward from there. Target is both Google Play and the App Store.

## Blocking — do not ship without this

**The OpenAI key is baked into the binary.** The current backup predates the Cloudflare Worker proxy. It ships the key via `--dart-define`, which means the key is in the APK. That has to move back to the proxy at `onesocial-ai-proxy.goldenapexapps.workers.dev` before any public release. The AI caption feature uses `AI_PROXY_URL` plus `APP_SHARED_SECRET`.

Key verification sequence, all in the same terminal window, before any Flutter build:

    export NEW_KEY="..."
    echo ${#NEW_KEY}
    curl test against the proxy
    then flutter commands

## Next up, in order

**iOS bundle ID.** Still `com.calvryth.onesocial` — legacy artifact from a dead entity. Change to `com.goldenapexapps.onesocial` before first App Store submission. Bundle IDs cannot be changed after publication, so this is a one-shot.

**NSFaceIDUsageDescription.** Must be non-empty or the build gets rejected.

**Subscriptions.** Three-tier model with introductory offers. Products have to be created in Play Console and App Store Connect.

**Store listings.** Screenshots, descriptions, content rating, data safety form.

## Deferred

Translation goes to v1.2 using `google_mlkit_translation` — on-device, free, 50+ languages. It lands in a separate v1.2 codebase copy, not the v1.0 rebuild. Do not let it creep back in.

## Legal — done

Privacy policy and 30-section Terms of Service are finalized and live at goldenapexapps.com. 18+ age minimum, California / Placer County venue, no arbitration, OpenAI named explicitly, Apple and Google store sections split. Provider-side prompt copies are acknowledged. "My server" was replaced with "Cloudflare server" throughout.

## Trademark

Search found zero live conflicts in Classes 009 and 042. ONE SOCIAL exists in Class 43 (bar services) — different class, but USPTO treats "1" and "ONE" as equivalents, so it is low risk but worth monitoring. Descriptiveness is a separate refusal risk. Fallbacks are a logo composite mark or the Supplemental Register.

## Things that will bite me if I forget

- Shell scripts: bare commands, no inline comments (zsh chokes), single self-contained script with heredocs, no zip files.
- Complete files only. No partial edits, no elided code. Bracket-verify before delivery.
- Before any build session: check `flutter --version` against latest stable, check the OS version on the target device, confirm Flutter supports it. iOS 26+ needs Flutter 3.38+ and `flutter config --enable-uiscene-migration`. App Store requires iOS 26 SDK and Xcode 26 as of April 28, 2026.
- `--no-enable-impeller` on the M1 Mac.

## Standing rules

Privacy-first. No ads, no tracking, no data collection or selling. All user data on-device by default. Nothing leaves the device unless the user explicitly authorizes it for a named opt-in feature.

No free AI feature that costs per-use API fees. AI is paid by the user or it is fully local.

## Test devices

- Z Fold 3 — `RFCT40JD22H`
- Z Fold 3 (2026 unit) — `RFCY81RK2BX`
- iPhone 17 Pro Max — `00008150-001E20891188401C`
- Apple team ID — `SZ744P7R4K`

---

## Session: 2026-08-13

### Folder confusion resolved
`one_private_social` (1.0.0+4) is the live codebase. `one_social_suite` (1.0.0+1)
is stale — same applicationId, no paywall, three builds behind. Marked with
DO_NOT_USE.txt. An hour was lost fixing the wrong folder before catching this.

### Fixed this session
- SDK 36 pinned (compileSdk and targetSdk) ahead of the Aug 31 Play deadline.
- Found that release builds were dropping both --dart-define values. The app
  reads AI_PROXY_URL and APP_SHARED_SECRET via String.fromEnvironment with
  defaultValue: ''. When empty, isConfigured returns false and AI captions
  silently fall back to the rules engine — no crash, no error, just no AI.
  Every prior release bundle shipped this way.
- APP_SHARED_SECRET rotated (old one was exposed in a terminal error). New value
  pushed to the onesocial-ai-proxy worker and saved to
  ~/.gaa_secrets/onesocial_shared_secret.txt.
- build_release.sh added to the repo so the defines can never be dropped again.

### Bundle verified clean
Proxy URL present, paywall present (3 tiers), no leaked API keys, no tracking
SDKs. The "firebase" string hit was a dead constant — no dependency, no
google-services.json, no dex classes, never initialized.

### Apple review — needs a decision
The 1PrivateSocial build currently in Apple review was built from the older +1
state, not +4. If approved, that stale version ships to iOS users. Decide
whether to let it through and follow with 1.0.1, or withdraw and resubmit from
one_private_social.

### Next up
1. Play Console: create app record, package com.goldenapexapps.onesocial
2. Upload the .aab to internal testing (no review wait)
3. Create the three subscriptions with IDs matching purchase_service.dart:
   com.goldenapexapps.onesocial.aiassist.{starter,plus,pro}
   plus the 2-month intro offers — the app already states an intro price
4. Receipt validation — still unconfigured, purchases cannot grant access
5. Test install on the Fold and confirm an AI caption actually returns

## 2026-08-19 — PUBLISHED on Google Play

Review cleared. Build 1.0.0+8 live. Purchase sheets verified on the Fold:
Starter shows 2-week free trial then $3.99/month, Plus shows $6.99/month.
Prices saved correctly on all three including Plus after the base plan mixup.

NEXT:
1. Setup > License testing - add Gmail BEFORE subscribing or the real card
   gets charged (sheet showed Visa-9533, not a test card)
2. Subscribe on the Fold, confirm AI Assist unlocks and the counter
   decrements once per platform
3. Paywall polish: tier cards show "Free" where the recurring price should
   be. Play's own sheet reads "2-week free trial, then $3.99/month" - match
   that by reading the offer phase AND base plan price from ProductDetails
4. iOS: rejected, resubmit from current code with matching pricing
