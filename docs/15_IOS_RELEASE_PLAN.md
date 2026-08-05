# 15_IOS_RELEASE_PLAN.md
# NutriScan — iOS Production Release Runbook

**Document type:** Release runbook (operational)
**Status:** Active
**Version:** 1.0.0
**Last updated:** 2026-08-04
**Parent documents:** [MASTER_PLAN.md](./MASTER_PLAN.md) · [plan.md](./plan.md) · [CLAUDE.md](../CLAUDE.md)
**Scope:** Everything required to take the existing Flutter app from "works on my device" to "live on the App Store", and to keep shipping after that.

---

## How this document relates to the others

| Document | Answers |
|----------|---------|
| `CLAUDE.md` (repo root) | Agent entry point — hard rules, extension points, who-does-what |
| `MASTER_PLAN.md` | *What* the product is and how it is architected |
| `plan.md` | *How* to implement the FKB / verified-nutrition feature work, phase by phase |
| **`15_IOS_RELEASE_PLAN.md`** (this) | *How to ship it* — accounts, signing, compliance, build, submit, operate |

Decisions recorded here that constrain code are written up as ADRs in
`MASTER_PLAN.md` Part 16: **ADR-009** (ads fail closed when unconfigured),
**ADR-010** (security rules versioned in the repo), **ADR-011** (account
deletion is cloud-first). Changing any of those requires appending a new ADR,
not editing this runbook.

`MASTER_PLAN.md` Part 13 and `plan.md` Phase 5 describe store readiness as a ~20-line checklist. That is a summary, not a runbook. This document is the executable version of those two sections and supersedes them where they conflict.

**Independence note:** the release track below can run in parallel with `plan.md` Phases 1B–4. You do not need the Food Knowledge Base finished to submit version 1. See § 10 for the two viable launch strategies.

---

## Table of contents

1. [Current state assessment](#1-current-state-assessment)
2. [Release blockers](#2-release-blockers)
3. [Apple accounts & App Store Connect setup](#3-apple-accounts--app-store-connect-setup)
4. [Environments & Firebase projects](#4-environments--firebase-projects)
5. [Xcode project & code signing](#5-xcode-project--code-signing)
6. [Compliance & privacy](#6-compliance--privacy)
7. [In-app purchases](#7-in-app-purchases)
8. [Build & upload](#8-build--upload)
9. [TestFlight & staging bake](#9-testflight--staging-bake)
10. [Store listing & submission](#10-store-listing--submission)
11. [Post-release operations](#11-post-release-operations)
12. [Rollback](#12-rollback)
13. [Appendix A — Pre-submit checklist](#appendix-a--pre-submit-checklist)
14. [Appendix B — Known rejection risks for this app](#appendix-b--known-rejection-risks-for-this-app)
15. [Appendix C — Command reference](#appendix-c--command-reference)

---

# 1. Current state assessment

Audited 2026-08-04 against commit on `main`.

## 1.1 What already exists

| Area | Status | Evidence |
|------|--------|----------|
| Flutter app, scan flow | Working | `lib/providers/food/food_provider.dart` |
| Firebase Auth (Google + Apple) | Working | `lib/services/auth/cloud_backup_service.dart` |
| Sign in with Apple entitlement | Present | `ios/Runner/Runner.entitlements` |
| Firebase App Check (App Attest) | Wired | `lib/main.dart` |
| Crashlytics + Analytics | Wired | `lib/main.dart`, `pubspec.yaml` |
| IAP + server-side verification | Present | `functions/src/index.ts` → `verifyPurchase` |
| Restore purchases | Present | `lib/services/payment/iap_service.dart` |
| Privacy Policy / Terms screens | Present | `lib/screens/legal/` |
| iOS bundle id + team | Set | `com.vin.nutrisnap`, team `KS362JT4QN` (updated 2026-08-05 — see § 3.1) |
| **Delete account** | **Added 2026-08-04** | `lib/services/auth/account_deletion_service.dart` |
| **ATT + SKAdNetwork + export compliance** | **Added 2026-08-04** | `ios/Runner/Info.plist` |
| **AdMob release guard** | **Added 2026-08-04** | `lib/config/ads_config.dart` |
| **Storage security rules** | **Added 2026-08-04** | `storage.rules` |

## 1.2 What does not exist yet

| Gap | Blocking? | Section |
|-----|-----------|---------|
| Real AdMob App ID + ad unit IDs | **Done 2026-08-05 (iOS)** — Android still open | § 6.4 |
| App Store Connect app record + IAP products | Yes | § 3, § 7 |
| Public Privacy Policy / Terms **URLs** | Yes | § 6.1 |
| App Privacy nutrition labels filled in | Yes | § 6.2 |
| APNs authentication key uploaded to Firebase | Yes (push is wired) | § 3.4 |
| Screenshots, description, keywords | Yes | § 10 |
| Reviewer demo account | Yes | § 10.3 |
| Separate staging Firebase project | No (recommended) | § 4 |
| Automated tests | **Done 2026-08-05** — `test/` directory now exists, see `CLAUDE.md` § 5 | § 9.4 |
| CI/CD pipeline | No (recommended) | § 8.4 |
| Localised strings for the new delete-account keys | No (English fallback works) | § 6.6 |

---

# 2. Release blockers

Ordered by severity. Nothing ships until every **P0** is closed.

## P0-1 — Delete account ✅ RESOLVED 2026-08-04

App Store Review Guideline **5.1.1(v)**: an app that lets a user create an account must let them initiate deletion of that account from inside the app. This is one of the most consistently enforced rejection reasons and there is no negotiating around it.

Implemented in `lib/services/auth/account_deletion_service.dart`:

- Deletes Firebase Storage `food_images/{uid}/**`
- Deletes Firestore `backups/{uid}` and `users/{uid}`
- Deletes the Firebase Auth user, with silent re-authentication when Firebase returns `requires-recent-login`
- Wipes local SQLite history and SharedPreferences (device id preserved)

UI: Settings → Data & Privacy → Delete Account. Typed "DELETE" confirmation, visible only when signed in.

**Deletion order is load-bearing.** Cloud data must go before the Auth user, because Firestore and Storage rules key off `request.auth.uid`. Delete the Auth user first and every subsequent write is rejected forever, leaving orphaned data — which is itself a privacy problem.

**Required deploy:** `firestore.rules` previously had no `allow delete` on `users/{userId}`, so the flow would have failed with `PERMISSION_DENIED`. Both rule files must be deployed before this ships:

```bash
firebase deploy --only firestore:rules,storage
```

**Verification (must be executed on a real device before submitting):**

| ID | Step | Expected |
|----|------|----------|
| D1 | Sign in, scan 2 foods, back up to cloud, delete account | Firestore `users/{uid}` and `backups/{uid}` gone in console |
| D2 | Check Storage `food_images/{uid}/` after D1 | Empty / no longer listed |
| D3 | Check Firebase Auth console after D1 | User no longer listed |
| D4 | Reopen app after D1 | Logged out, empty history, no crash |
| D5 | Sign in >5 min before deleting (stale token) | Re-auth prompt appears, deletion completes on retry |
| D6 | Airplane mode, tap delete | Clear error message, account still intact, no partial wipe reported as success |

## P0-2 — AdMob production IDs ⚠️ OPEN

`ios/Runner/Info.plist` currently carries `ca-app-pub-3940256099942544~1458002511` — Google's **public sample app ID**. Shipping it violates AdMob policy, earns nothing, and signals an unfinished build to reviewers.

The Dart side is now fail-safe: `AdsConfig.adsEnabled` returns `false` in release builds while the production ad unit IDs are unset, so no test ads will be requested from a store build. The Info.plist App ID still needs replacing by hand.

**To close:**

1. AdMob console → Apps → NutriScan (iOS) → App settings → copy **App ID** (`ca-app-pub-…~…`).
2. Replace `GADApplicationIdentifier` in `ios/Runner/Info.plist`.
3. Create four ad units (App open, Banner, Interstitial, Rewarded) → paste each **ad unit ID** (`ca-app-pub-…/…`) into the `_ios*Production*AdUnitId` constants in `lib/config/ads_config.dart`.
4. Repeat for Android in `android/app/src/main/AndroidManifest.xml`.
5. Confirm with `AdsConfig.configurationReport()` in a profile build.

**Alternative:** ship v1.0 with `_adsEnabledByConfig = false`. This removes the entire ATT / advertising-data surface from review, and ads can be enabled in v1.1 once the AdMob account is approved. Given that AdMob account approval can take days and is a common launch delay, this is the lower-risk path.

## P0-3 — Legal URLs must be publicly reachable ⚠️ OPEN

The app has in-app Privacy Policy and Terms screens, but App Store Connect requires a **public HTTPS URL** for the privacy policy — reviewers and the store listing both need it. In-app screens do not satisfy this.

See § 6.1.

## P0-4 — App Store Connect record + IAP products ⚠️ OPEN

IAP cannot be tested in TestFlight sandbox until the products exist and **Paid Apps Agreement + tax + banking** are active. This has a multi-day lead time and is the single most common cause of a slipped launch date. Start it first.

See § 3 and § 7.

## P1 — Recommended before v1.0

- Separate staging Firebase project (§ 4)
- Smoke test suite executed manually (§ 9.3)
- Delete-account strings translated to the 14 non-English locales (§ 6.6)
- Fix `lib/main.dart` debug-only Cloud Functions emulator redirect — verify it is `kDebugMode`-gated (it is) and that release builds hit production

---

# 3. Apple accounts & App Store Connect setup

Start this section **before** any code work. Everything here has external lead time.

## 3.1 Apple Developer Program

- Enrolled organisation or individual account, US$99/year, active.
- Team ID `KS362JT4QN` is already referenced in the Xcode project (updated
  2026-08-05, replacing the earlier `U5Y77MA4F9` — see `CLAUDE.md`'s Apple Dev
  Personal Team note for why) — confirm it matches the account you intend to
  publish from.
- Roles needed: **Account Holder** for agreements, **Admin** or **App Manager** for App Store Connect work.

## 3.2 Agreements, Tax, and Banking

App Store Connect → Business.

- [ ] **Paid Applications Agreement** accepted (required for IAP — free apps with IAP still need it)
- [ ] Bank account added and validated
- [ ] Tax forms completed for every region you intend to sell in (US W-8BEN/W-9 at minimum)

> Until this shows **Active**, IAP products stay in "Waiting for Upload" / "Missing Metadata" and sandbox purchases fail with unhelpful errors. Budget 1–5 business days.

## 3.3 App record

App Store Connect → My Apps → **+** → New App.

| Field | Value |
|-------|-------|
| Platform | iOS |
| Name | NutriScan (must be globally unique — check availability early) |
| Primary language | English (US) |
| Bundle ID | `com.vin.nutrisnap` — register in Certificates, Identifiers & Profiles first |
| SKU | e.g. `NUTRISCAN-IOS-001` (internal only) |
| User Access | Full Access |

**App ID capabilities** (Certificates, Identifiers & Profiles → Identifiers → `com.vin.nutrisnap`) — enable all of these, they are all used by the current code:

- [ ] Push Notifications (FCM)
- [ ] Sign in with Apple (entitlement already in the project)
- [ ] In-App Purchase
- [ ] App Attest (Firebase App Check `AppleAppAttestProvider`)
- [ ] Associated Domains — only if you add deep links later

## 3.4 APNs key for Firebase Cloud Messaging

`firebase_messaging` is initialised at startup and topics are subscribed on launch, so push is not optional-if-broken — a missing key produces silent failures.

1. Certificates, Identifiers & Profiles → Keys → **+** → enable **Apple Push Notifications service (APNs)**.
2. Download the `.p8`. **It can only be downloaded once** — store it in a password manager, not the repo.
3. Firebase console → Project settings → Cloud Messaging → iOS app → upload the `.p8` with its Key ID and your Team ID.
4. Confirm the `aps-environment` entitlement is `production` for release builds (Xcode manages this automatically with the Push Notifications capability enabled).

---

# 4. Environments & Firebase projects

## 4.1 Current state

One Firebase project, `nutriscan-75d57`, used for everything. Acceptable for a first launch; risky afterwards, because a bad Cloud Functions deploy or a Firestore rules mistake hits live users directly.

## 4.2 Recommended target

| Environment | Firebase project | Bundle ID | Distribution |
|-------------|------------------|-----------|--------------|
| dev | `nutriscan-dev` | `com.vin.nutrisnap.dev` | Local + emulators |
| staging | `nutriscan-staging` | `com.vin.nutrisnap.staging` | TestFlight internal |
| prod | `nutriscan-75d57` | `com.vin.nutrisnap` | App Store |

Implement with Xcode build configurations and per-configuration `GoogleService-Info.plist` files, plus `--dart-define=ENV=staging`. Distinct bundle IDs let all three coexist on one device.

**Migration is not required for v1.0.** If you stay single-project, compensate with: staged rollout, a 48-hour TestFlight bake, and never deploying Functions and an app build in the same hour.

## 4.3 Secrets

Confirm before every release that none of these are in the Flutter tree or in git:

- `GROQ_API_KEY` — Functions/Secret Manager only
- `USDA_FDC_API_KEY` — Functions/Secret Manager only
- APNs `.p8`, App Store Connect API key `.p8` — password manager only

```bash
# Should return nothing
git grep -nE "(gsk_|AIza[0-9A-Za-z_-]{20,}|BEGIN PRIVATE KEY)" -- nutriscan/lib nutriscan/ios
```

> `GoogleService-Info.plist` and `google-services.json` are *not* secrets — they are client identifiers and are safe in the repo. App Check and security rules are what protect the backend.

---

# 5. Xcode project & code signing

## 5.1 Toolchain requirement — verify before you build

As of **28 April 2026**, apps uploaded to App Store Connect must be built with **Xcode 26 or later**, using the **iOS 26 SDK or later**. An older Xcode will have its upload rejected at the pipeline stage with a message that does not always make the cause obvious.

- [ ] `xcodebuild -version` reports 26.x or newer
- [ ] Flutter version is recent enough to support that Xcode (`flutter doctor -v`)
- [ ] `IPHONEOS_DEPLOYMENT_TARGET` is currently **13.0** — newer Xcode releases raise the minimum supported deployment target. If Xcode 26 refuses it, raise to the lowest value it accepts and re-run the full smoke suite, since some plugins behave differently across that boundary.

## 5.2 Signing

Automatic signing is enabled (`CODE_SIGN_STYLE = Automatic`) and is fine for a solo developer.

- [ ] Xcode → Runner → Signing & Capabilities → Team = the publishing team
- [ ] "Automatically manage signing" checked for the **Release** configuration
- [ ] `CODE_SIGN_IDENTITY[sdk=iphoneos*]` — currently `iPhone Developer`. Confirm the Release configuration resolves to an **Apple Distribution** certificate; `iPhone Developer` will not archive for the store.

For CI, switch to manual signing with a distribution certificate and an App Store provisioning profile stored in a `match`-style encrypted repo.

## 5.3 Versioning

`ios/Runner/Info.plist` correctly derives both values from Flutter:

- `CFBundleShortVersionString` = `$(FLUTTER_BUILD_NAME)` → `2.1.2` from `pubspec.yaml`
- `CFBundleVersion` = `$(FLUTTER_BUILD_NUMBER)` → `1` from `pubspec.yaml`

So `pubspec.yaml` `version:` is the single source of truth. Good — leave it that way.

**Rules:**

- The build number must be **strictly greater** than any build previously uploaded for that version string. It can never be reused, even for a rejected build.
- Bump `+N` for every upload: `2.1.2+1` → `2.1.2+2` → …
- Bump the version string for every user-visible release: `2.1.2` → `2.1.3`.
- `app_version_subtitle` in `lib/config/app_localizations.dart` is hardcoded to `2.1.2`. Update it in the same commit as any version bump, or it will drift.

The `RunnerTests` target bundle ID was originally `com.example.nutriscan.RunnerTests`, corrected to `com.nutriscan.app.RunnerTests` (2026-08-04), and now tracks the app's real bundle: `com.vin.nutrisnap.RunnerTests` (2026-08-05). A `com.example.*` identifier anywhere in the project is a recognisable "template not finished" signal.

---

# 6. Compliance & privacy

## 6.1 Legal URLs

You need two publicly reachable HTTPS pages. GitHub Pages, a Notion public page, or Firebase Hosting are all acceptable — content matters, hosting does not.

- [ ] Privacy Policy URL — entered in App Store Connect → App Privacy, **required**
- [ ] Terms of Use URL — required in the listing if you sell subscriptions
- [ ] Both URLs also linked from inside the app (already satisfied by `lib/screens/legal/`)

The privacy policy must actually describe what this app does, which is more than the template default:

- Photos captured or selected are sent to a server for AI analysis
- Which AI providers process them, and whether images are retained
- Firebase Analytics and Crashlytics collection
- AdMob advertising identifiers, if ads ship
- Nutrition data stored locally and, for premium users, in cloud backup
- How to delete an account and what deletion removes

## 6.2 App Privacy nutrition labels

App Store Connect → App Privacy. These must match observable app behaviour — mismatches are caught in review and are treated as misrepresentation rather than a formatting error.

Based on the current dependency set, expect to declare at minimum:

| Data type | Collected | Linked to user | Tracking | Why |
|-----------|-----------|----------------|----------|-----|
| Email address | Yes | Yes | No | Firebase Auth |
| Name | Yes | Yes | No | Google / Apple sign-in profile |
| User ID | Yes | Yes | No | Firebase uid |
| Photos | Yes | Yes | No | Meal images sent for analysis |
| Health & Fitness | Yes | Yes | No | Nutrition logs |
| Purchase history | Yes | Yes | No | IAP verification |
| Crash data | Yes | No | No | Crashlytics |
| Performance data | Yes | No | No | Crashlytics / Analytics |
| Product interaction | Yes | No | No | Analytics |
| Device ID / Advertising data | Yes | — | **Yes** | AdMob — **only if ads ship** |

> The "Tracking" column is what triggers the ATT requirement. If you launch without ads, remove the last row and the app arguably does no tracking at all — a materially simpler review.

## 6.3 App Tracking Transparency ✅ RESOLVED 2026-08-04

`NSUserTrackingUsageDescription` is now present in `Info.plist`, `app_tracking_transparency` is in `pubspec.yaml`, and `_requestTrackingAuthorization()` in `lib/main.dart` runs **before** `MobileAds.instance.initialize()` — the order Google requires so the SDK can pick up the IDFA when granted.

- [ ] Run `flutter pub get` and `cd ios && pod install` to pick up the new plugin
- [ ] Verify on a physical device that the prompt appears exactly once on first launch
- [ ] Verify declining the prompt leaves every feature working

## 6.4 SKAdNetwork ✅ RESOLVED 2026-08-04

50 `SKAdNetworkIdentifier` entries from Google's official list are now in `Info.plist`. Re-check that list before each release — Google adds buyers over time. If you enable AdMob mediation, append each mediated network's identifiers as well.

## 6.5 Export compliance ✅ RESOLVED 2026-08-04

`ITSAppUsesNonExemptEncryption` is set to `false`. NutriScan uses only OS-provided HTTPS/TLS, which is exempt. This skips the encryption questionnaire on every upload.

> If you later add your own cryptography (not just TLS), this must be revisited — a false declaration is a compliance violation, not a paperwork slip.

## 6.6 Privacy manifests

Since May 2024, apps and third-party SDKs must ship `PrivacyInfo.xcprivacy` declaring required-reason API usage and data collection. Xcode merges every manifest into a Privacy Report at archive time.

- Current Firebase, Google Mobile Ads, and most maintained Flutter plugins ship their own manifests. Keeping dependencies current is most of the work.
- If **NutriScan's own code** uses a required-reason API — `UserDefaults` (via `shared_preferences`), file timestamps, disk space, active keyboards, system boot time — add an app-level `PrivacyInfo.xcprivacy` to `ios/Runner/` with the appropriate reason codes. `shared_preferences` covers its own usage, but verify in the generated Privacy Report rather than assuming.

**Check:** Xcode → Product → Archive → Organizer → right-click the archive → **Generate Privacy Report**. Review before uploading.

## 6.7 Health claims copy audit

Guideline 1.4.1 and 5.2 territory. This is a nutrition app with AI-estimated numbers, so the copy has to stay honest.

- [ ] No use of "diagnose", "treat", "cure", "prescribe", "medical-grade", "clinically proven", "guaranteed accurate"
- [ ] A nutrition disclaimer is reachable within two taps of Settings
- [ ] Screenshots and the App Store description carry no medical claims
- [ ] AI-estimated values are visibly labelled as estimates (this is what `plan.md` Phase 1D delivers — until then, ensure existing copy does not imply verified accuracy)

## 6.8 Age rating

Answer the questionnaire honestly. A general nutrition tracker with ads is typically **4+**, but note:

- If the app can produce weight-loss or restrictive-diet guidance, expect questions about "Medical/Treatment Information"
- The AI health coach is free-text output — if it can discuss diet plans, declare accordingly

## 6.9 Account deletion ✅ RESOLVED

See § 2 / P0-1.

## 6.10 Sign in with Apple ✅ SATISFIED

Guideline 4.8: an app offering third-party sign-in must also offer Sign in with Apple. Google Sign-In is offered, and so is Apple. The entitlement is present. No action.

---

# 7. In-app purchases

## 7.1 Product setup

App Store Connect → your app → Monetization → In-App Purchases / Subscriptions.

For each product:

- [ ] Product ID matches **exactly** the ID in `lib/services/payment/iap_service.dart` — a mismatch means the paywall renders empty and review rejects it as a broken feature
- [ ] Reference name, display name, description
- [ ] Price tier per territory
- [ ] Localised display name + description for every listing language
- [ ] **Review screenshot** of the purchase screen (required per product, commonly forgotten)
- [ ] Subscription group configured, with duration and free-trial/intro offer if used
- [ ] Status reaches "Ready to Submit"

## 7.2 Subscription disclosure

Guideline 3.1.2 requires, on the purchase screen itself and in the listing:

- [ ] Subscription title and length
- [ ] Price per period, in local currency
- [ ] "Auto-renews unless cancelled at least 24 hours before the end of the period"
- [ ] Links to Terms of Use and Privacy Policy **on the paywall screen**, tappable
- [ ] Clear statement of what free vs premium unlocks

## 7.3 Restore purchases

- [ ] "Restore Purchases" button is discoverable without an account (Guideline 3.1.1)
- [ ] Tested in sandbox: delete app → reinstall → restore → entitlement returns
- [ ] Restoring produces clear success/failure feedback

## 7.4 Coins and ads interaction

Coins unlock digital functionality, so they must be purchased through IAP where purchasable — earning them by watching rewarded ads is fine and does not require IAP.

- [ ] No path exists to buy coins outside StoreKit
- [ ] Premium correctly bypasses the coin gate
- [ ] `verifyPurchase` Cloud Function is deployed and reachable from a release build

## 7.5 Sandbox testing

Create a Sandbox Apple ID in App Store Connect → Users and Access → Sandbox Testers. Sign into it on-device under Settings → App Store → Sandbox Account, **not** the main Apple ID.

| ID | Test | Expected |
|----|------|----------|
| P1 | Purchase monthly subscription | Entitlement granted, `verifyPurchase` logs success |
| P2 | Cancel and let it lapse | Entitlement revoked at expiry |
| P3 | Restore after reinstall | Entitlement returns |
| P4 | Purchase coins | Balance increases exactly once |
| P5 | Kill the app mid-purchase | No double-grant, no lost purchase on relaunch |
| P6 | Purchase with no network | Clean error, no phantom entitlement |

---

# 8. Build & upload

## 8.1 Pre-build

```bash
cd nutriscan
flutter clean
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter analyze                 # must be clean
```

## 8.2 Deploy backend first

Always ship the backend before the client that depends on it.

```bash
cd nutriscan
firebase deploy --only firestore:rules,storage
firebase deploy --only functions
```

- [ ] Firestore rules include the new `allow delete` on `users/{userId}`
- [ ] Storage rules deployed from `storage.rules`
- [ ] Functions secrets (`GROQ_API_KEY`, `USDA_FDC_API_KEY`) present in the prod project
- [ ] App Check enforcement enabled for the callable functions

## 8.3 Archive

```bash
flutter build ipa --release
```

Then Xcode → Window → Organizer → select the archive → **Distribute App** → App Store Connect → Upload.

Or headless:

```bash
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

(`altool` is deprecated in favour of `xcrun notarytool` / Transporter for some workflows — check what your Xcode version recommends.)

- [ ] Build number incremented
- [ ] Release configuration, not Debug or Profile
- [ ] Privacy Report reviewed (§ 6.6)
- [ ] `AdsConfig.configurationReport()` output matches your intent

## 8.4 CI (optional, recommended after v1.0)

`fastlane` with `match` for signing and `pilot` for TestFlight, driven by an App Store Connect API key. Store the key as a CI secret. Recommended pipeline:

```
PR      → flutter analyze → flutter test
main    → build ipa → upload to TestFlight → notify
tag v*  → promote the TestFlight build to App Store review
```

---

# 9. TestFlight & staging bake

## 9.1 Internal testing

- Up to 100 internal testers, available immediately after processing, no review needed.
- [ ] Add yourself and anyone who will run the smoke suite
- [ ] Confirm the build processes without an "Invalid Binary" email

## 9.2 External testing

- Up to 10,000 testers, requires a **Beta App Review** (usually under 24 hours, but it can be longer — do not schedule around the fast case).
- [ ] Beta App Description and feedback email filled in
- [ ] Test information includes a demo account if sign-in is required

## 9.3 Smoke suite — run on a physical device before every submission

Extends the suite in `plan.md`. All must pass.

| ID | Steps | Expected |
|----|-------|----------|
| S1 | Deny camera permission | Clear message, no crash |
| S2 | Free user with 0 coins taps scan | No-coin dialog, no AI call |
| S3 | Photograph a non-food object | NOT_FOOD path handled |
| S4 | Photograph a common food | Result saved, numbers sensible |
| S5 | Airplane mode mid-scan | Error shown, DB intact after relaunch |
| S6 | History screen | Newest scan first, no exceptions |
| S7 | Sign in with Apple | Succeeds, profile populated |
| S8 | Sign in with Google | Succeeds |
| S9 | Purchase subscription (sandbox) | Entitlement granted |
| S10 | Restore purchases after reinstall | Entitlement returns |
| S11 | **Delete account (D1–D6, § 2)** | All pass |
| S12 | ATT prompt on first launch | Appears once; declining breaks nothing |
| S13 | Push notification from Firebase console | Received in foreground and background |
| S14 | Dark mode across every screen | Legible, adequate contrast |
| S15 | Switch language, walk the app | No raw localization keys visible |
| S16 | Cold launch, timed | Home visible in ≤ 2.5s on a mid-range device |

## 9.4 Automated tests

There is no `test/` directory. Not a blocker for v1.0, but before the app has real users, add at least:

- Unit tests for nutrient scaling math (`nutrient_per_100g × grams / 100`)
- Unit tests for `Food.toMap` / `fromMap` round-tripping
- A migration test for the Phase 2 SQLite upgrade path
- A widget test for the paywall rendering with mock products

## 9.5 Bake period

- [ ] Minimum 48 hours on TestFlight before submitting
- [ ] Crashlytics shows no new fatal issues
- [ ] Cloud Functions error rate is flat
- [ ] AI spend per active user is within budget

---

# 10. Store listing & submission

## 10.1 Two launch strategies

**Strategy A — Ship the current app first (recommended)**

Submit the existing scan/plan/coach app once the P0 blockers close. Ship the FKB verified-nutrition work from `plan.md` as version 2.0. Gets you into review sooner and surfaces process problems while the stakes are low.

Requires care with copy: without the FKB, every number is an AI estimate, so the listing must not imply verified accuracy.

**Strategy B — Ship after `plan.md` Phase 1D**

Launch with verified/estimated badges already in place. A stronger product and safer copy, but adds roughly 4–6 weeks and stacks the risk of a first submission on top of a large feature landing.

## 10.2 Listing assets

| Asset | Requirement |
|-------|-------------|
| App name | ≤ 30 characters |
| Subtitle | ≤ 30 characters — no medical claims |
| Description | ≤ 4000 characters |
| Keywords | ≤ 100 characters, comma-separated, no spaces |
| Screenshots | 6.9" and 6.5" iPhone sizes required; iPad only if you declare iPad support |
| App preview video | Optional |
| App icon | 1024×1024 PNG, no alpha, no rounded corners |
| Support URL | Required |
| Marketing URL | Optional |

The project currently declares iPad orientations in `Info.plist`. Either ship iPad screenshots and verify the layouts, or set the target to iPhone-only. A stretched iPhone layout on iPad is a routine rejection.

## 10.3 App Review Information

- [ ] **Demo account** — a working email/password or a pre-provisioned Google/Apple test account. Sign-in-gated content without a demo account is an automatic rejection.
- [ ] Notes explaining anything non-obvious: how the coin economy works, what the AI does with photos, why camera access is needed, that nutrition figures are estimates.
- [ ] Contact phone and email that someone actually monitors.

## 10.4 Release options

| Option | When to use |
|--------|-------------|
| Manual release | First launch — you control the moment it goes live |
| Automatic on approval | Later, routine updates |
| Phased release (7 days) | **Recommended for every version** — 1/2/5/10/20/50/100% |

Phased release lets you halt distribution if Crashlytics spikes. Use it from v1.0 onward.

## 10.5 Expected review timeline

Typically 24–48 hours; occasionally a week. Rejections are normal and usually cheap to fix — read the exact guideline number cited, fix precisely that, and reply in Resolution Center rather than resubmitting blind.

---

# 11. Post-release operations

## 11.1 First 72 hours

| Cadence | Check |
|---------|-------|
| Hourly, day 1 | Crashlytics crash-free rate (target ≥ 99.5%) |
| Daily | AI spend, Cloud Functions error rate |
| Daily | New reviews and ratings |
| Daily | IAP conversion and refund rate |

## 11.2 Ongoing

- Weekly: Crashlytics top issues, top unmatched food names (once FKB ships), MAPE if prompts changed
- Per release: full smoke suite, phased rollout, Privacy Report review
- Quarterly: re-check SKAdNetwork list, privacy manifest requirements, Apple's upcoming-requirements page

## 11.3 Alerts worth configuring

- [ ] Crashlytics velocity alerts → email/Slack
- [ ] GCP budget alert on the Firebase project (AI spend can move fast)
- [ ] Cloud Functions error-rate alert
- [ ] App Store Connect notifications for review status changes

---

# 12. Rollback

There is no "unpublish this version" button on iOS. Plan accordingly.

| Situation | Response |
|-----------|----------|
| Crash spike during phased release | **Pause the phased release** in App Store Connect — stops new users receiving it immediately. Fastest lever available. |
| Critical bug, already 100% released | Submit a fix and request **expedited review** with a clear justification. Sparingly — abusing it burns credibility. |
| Bad backend deploy | Roll back Cloud Functions (`firebase functions:delete` + redeploy previous, or redeploy from the previous tag). Faster than any app-side fix. |
| Bad feature behaviour | Kill it with a Remote Config / server flag. **This is why `MASTER_PLAN.md` ADR-008 requires feature flags** — it is the only true rollback path for shipped client code. |
| Bad security rules | Redeploy the previous `firestore.rules` / `storage.rules` from git. Seconds. |

**Consequence:** every risky client-side feature must sit behind a server-controlled flag before it ships. Client code you cannot disable remotely is code you cannot roll back.

---

# Appendix A — Pre-submit checklist

Print this. Do not submit until every box is ticked.

### Accounts
- [ ] Apple Developer Program active
- [ ] Paid Applications Agreement **Active**, tax and banking complete
- [ ] App record created, bundle ID registered
- [ ] Capabilities enabled: Push, Sign in with Apple, IAP, App Attest
- [ ] APNs `.p8` uploaded to Firebase

### Code
- [ ] `flutter analyze` clean
- [ ] Version and build number bumped; build number never reused
- [ ] `app_version_subtitle` matches `pubspec.yaml`
- [ ] No secrets in the Flutter tree or in git
- [ ] Release build points at production Firebase (emulator redirect is `kDebugMode`-gated)
- [ ] Real AdMob App ID in `Info.plist` **or** ads disabled via `_adsEnabledByConfig`
- [ ] `AdsConfig.configurationReport()` output matches intent

### Backend
- [ ] `firestore.rules` deployed, including `allow delete` on `users/{userId}`
- [ ] `storage.rules` deployed
- [ ] Functions deployed; secrets present
- [ ] App Check enforcement on

### Compliance
- [ ] Privacy Policy URL live and accurate
- [ ] Terms of Use URL live
- [ ] App Privacy labels match actual behaviour
- [ ] `NSUserTrackingUsageDescription` present; ATT prompt verified on device
- [ ] `SKAdNetworkItems` current
- [ ] `ITSAppUsesNonExemptEncryption` set
- [ ] Privacy Report generated and reviewed
- [ ] No medical claims in app copy, screenshots, or description
- [ ] Nutrition disclaimer within two taps of Settings
- [ ] Age rating questionnaire completed

### Features
- [ ] **Delete account: D1–D6 all pass on a real device**
- [ ] Restore purchases works after reinstall
- [ ] Sign in with Apple works
- [ ] IAP sandbox tests P1–P6 pass
- [ ] Smoke suite S1–S16 pass

### Listing
- [ ] Screenshots for every declared device size
- [ ] Description, subtitle, keywords final
- [ ] Support URL live
- [ ] **Demo account provided and verified working**
- [ ] Review notes explain coins, AI photo handling, estimate disclaimer
- [ ] Phased release enabled

### Build
- [ ] TestFlight bake ≥ 48h
- [ ] Crashlytics clean during bake
- [ ] Uploaded build processed without warnings

---

# Appendix B — Known rejection risks for this app

Ranked by likelihood given what NutriScan actually does.

| # | Risk | Guideline | Mitigation |
|---|------|-----------|------------|
| 1 | No in-app account deletion | 5.1.1(v) | ✅ Implemented — verify D1–D6 |
| 2 | Health claims in copy | 1.4.1 / 5.2 | Copy audit § 6.7 |
| 3 | Reviewer cannot sign in | 2.1 | Demo account § 10.3 |
| 4 | Subscription terms not disclosed on the paywall | 3.1.2 | § 7.2 |
| 5 | Privacy labels contradict behaviour | 5.1.1 | § 6.2 |
| 6 | Ads with no ATT prompt | 5.1.2 | ✅ Implemented — verify on device |
| 7 | Google sample AdMob ID shipped | AdMob policy | § 2 / P0-2 |
| 8 | Restore purchases missing or broken | 3.1.1 | § 7.3 |
| 9 | Broken iPad layout while declaring iPad support | 2.1 / 4.0 | § 10.2 |
| 10 | AI produces unsafe dietary advice | 1.4.1 | Coach system prompt hardening — `plan.md` Phase 4, W4.2 |
| 11 | Camera permission string too vague | 5.1.1 | Current strings are specific — keep them that way |
| 12 | Placeholder or lorem-ipsum content anywhere | 2.1 | Sweep before submitting |

---

# Appendix C — Command reference

```bash
# ── Environment ──────────────────────────────────────────────────────
flutter doctor -v
xcodebuild -version                    # must be 26.x or later

# ── Clean build ──────────────────────────────────────────────────────
cd nutriscan
flutter clean && flutter pub get
cd ios && pod install --repo-update && cd ..
flutter analyze

# ── Backend (deploy BEFORE the app) ──────────────────────────────────
firebase deploy --only firestore:rules,storage
firebase deploy --only functions
firebase functions:secrets:access GROQ_API_KEY      # verify presence

# ── Release build ────────────────────────────────────────────────────
flutter build ipa --release
open build/ios/archive/Runner.xcarchive             # → Organizer → Distribute

# ── Secret sweep ─────────────────────────────────────────────────────
git grep -nE "(gsk_|AIza[0-9A-Za-z_-]{20,}|BEGIN PRIVATE KEY)" -- nutriscan/lib nutriscan/ios

# ── Verify Info.plist compliance keys ────────────────────────────────
python3 -c "import plistlib;d=plistlib.load(open('nutriscan/ios/Runner/Info.plist','rb'));\
print('ATT:',bool(d.get('NSUserTrackingUsageDescription')));\
print('SKAdNetwork:',len(d.get('SKAdNetworkItems',[])));\
print('Encryption:',d.get('ITSAppUsesNonExemptEncryption'));\
print('AdMob:',d.get('GADApplicationIdentifier'))"
```

---

# Document control

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-08-04 | Initial runbook. Records the compliance fixes landed the same day: delete account, ATT, SKAdNetwork, export compliance, AdMob release guard, storage rules, RunnerTests bundle ID. |

**End of 15_IOS_RELEASE_PLAN.md v1.0.0**

> Contradictions between this runbook and `MASTER_PLAN.md` Part 13 / `plan.md` Phase 5 resolve in favour of this document, which is the operational source of truth for shipping. Product and architecture decisions still resolve in favour of `MASTER_PLAN.md`.
