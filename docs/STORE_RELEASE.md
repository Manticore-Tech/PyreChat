# Pyre Social Store Release Control Sheet

**Target:** Apple App Store + Google Play by 2026-10-31  
**Release scope:** owner-directed v1.0.11+13 RCS-first text alpha; do not advertise legacy account, Pyre/media or MLS features that the new home screen no longer exposes.

## Product identity

| Item | Value |
| --- | --- |
| Product name | Pyre Social |
| Android package | `dev.pyrearms.pyrechat_flutter` |
| iOS bundle ID | `dev.pyrearms.pyrechatFlutter` |
| Flutter release candidate | `1.0.11+13` |
| Production direct Android | `1.0.2+4` (until candidate published) |
| Production origin | `https://pyre.social` |
| Privacy URL | `https://pyre.social/privacy` |
| Terms URL | `https://pyre.social/terms` |
| Account deletion URL | `https://pyre.social/account/delete` |
| Support URL | `https://pyre.social/support` |

These public URLs are live and verified publicly. Source and production `/api/app` now advertise the canonical Play package `dev.pyrearms.pyrechat_flutter`; the retired `dev.pyrearms.chat` metadata override is no longer live.

## Release features in scope

- first-party RCS handle allocated on-device and bound to a local Ed25519 signing key;
- independent `messages.pyre.social` backend with direct CPIM text send, durable history and SIP/WSS notifications;
- peer messaging by copied SIP address/short handle;
- basic typing and delivered/displayed receipts;
- Android and Flutter web RCS inbox/thread screens;
- public privacy/terms/support/deletion-information pages.

Not in the current RCS app shell: legacy password signup/login, social profiles, Pyres, image/video capture, friend discovery, push notification delivery, group chats, automatic cross-device recovery, full E2EE or carrier/telephone-number RCS. Older code/SDKs remain in the build tree but are not active from the RCS entry point.

## Permissions

### Android

Current manifest:

- Internet
- Camera
- Microphone
- Notifications
- optional camera hardware feature

No location permission.
No notification-policy/global Do Not Disturb special access.

### iOS

Current usage descriptions:

- Camera
- Microphone
- Photo Library read
- Photo Library add

Push Notifications entitlement is staged in `Runner.entitlements`.
No location usage description is present because the store-release Flutter shell does not request location.

## Data inventory for store privacy forms

This is an engineering inventory for **v1.0.11+13 RCS alpha**, not a completed Play/App Store filing. Separate legacy PyreChat D1/R2 data may still exist while account deletion cleanup remains blocked by infrastructure permissions; never represent historical data as already erased.

### RCS identity / security

- Random public SIP handle and Ed25519 public key in the standalone RCS Worker.
- The device stores the private signing seed and bearer session in platform secure storage (Android Keystore / iOS Keychain; WebCrypto-backed browser storage). The private seed must never be transmitted to the server.
- Challenge requests, session token hashes, account events and service security/rate-limit state are processed to authenticate the account.

### Messages

- **Current RCS text is not E2EE.** The independent Worker stores and forwards plaintext message/CPIM content and sender/recipient addresses.
- The server stores history, delivery/read status and basic timestamps. Typing is live-only and not presented as permanent chat content.
- Basic identity/message account deletion exists server-side, but self-service deletion UI for the new RCS identity must be reviewed before public store submission.

### Compiled SDK and legacy data boundaries

- Android binary contains camera, microphone and notification permissions and SDK dependencies left from the legacy code tree, even though the current RCS-first screen does not expose those features. Reconcile final binary permissions and provider disclosures rather than claiming those dependencies are absent.
- Legacy user IDs, password/recovery records, media, tickets and other D1/R2 content belong to the retired service, not to the new RCS signup. Old signup/login routes were retired; production D1 account-data purge has not been verified.
- Product intent remains no sale of personal data, no advertising targeting from private messages and no cross-app ad tracking; independently audit analytics integrations and final provider disclosures.

## Third-party infrastructure / SDK review

Current relevant components:

- Cloudflare Worker / D1 / R2 / Durable Objects;
- Firebase Cloud Messaging for Android and staged iOS push;
- Apple APNs through Firebase Messaging on iOS;
- optional Snap Camera Kit provider, feature-gated and not required by Pyre Social;
- Flutter/Google ML Kit dependencies used by the independent camera/effects implementation.

Before store upload, verify the final SDK versions, privacy manifests, data-safety disclosures and terms for every enabled third-party SDK.

## Android release gate

Required:

- target SDK 36;
- stable release signing key;
- canonical Firebase Android config;
- release AAB;
- release APK for physical acceptance;
- production backend compatible with the release client;
- physical notification/offline/media/account-deletion QA.

Local workflow artifact:

- `pyrechat-android-play` -> `build/app/outputs/bundle/release/app-release.aab`

## iOS release gate

Required:

- Xcode 26+ / iOS 26 SDK store archive;
- `dev.pyrearms.pyrechatFlutter` App ID;
- Apple Distribution certificate;
- App Store provisioning profile with production Push Notifications;
- real Firebase `GoogleService-Info.plist` for the same bundle ID;
- APNs configured for the Firebase iOS app;
- signed IPA/archive validation;
- real-iPhone notification, Keychain, camera, video and notification-tap QA.

GitHub secret for Firebase config:

- `FIREBASE_IOS_GOOGLE_SERVICE_INFO_PLIST`

The real plist is ignored from source control.

## Backend deployment gate

- Standalone RCS Worker `pyresocial-messaging` at `messages.pyre.social` has independent account storage, bearer auth and SIP/WebSocket/CPIM/IMDN handlers. Owner-enabled enrollment (`ENROLLMENT_ENABLED=1`) and real two-account CPIM/receipt/WSS production tests passed on 2026-10-09.
- Flutter RCS web client is deployed at `https://pyre.social/app/`; the site also keeps `/privacy`, `/terms`, `/support`, `/account/delete` and `/api/download/android` routes.
- Legacy site signup/login/recovery are retired at edge with 410 for auth requests. The old D1/legacy media data are **not erased**; the scoped cleanup requires separate verified D1/R2 maintenance capability.
- Flutter Android v1.0.4+6 has passed 198 tests, Android API36 emulator startup and actual inbound/outbound first-party RCS messaging. Direct website APK still needs an R2-writable deployment credential (observed 401 from current Wrangler OAuth).

## Safety / review gate

- No public stranger discovery or algorithmic feed is enabled by the RCS-only entry point.
- RCS alpha does not yet have in-app report/block, mature abusive-sender mitigation, minor-specific safety controls or accessible recovery. These remain explicit gates for broad consumer publication, regardless of the successful owner/buddy alpha test.
- Plaintext CPIM RCS messages must never be marketed as end-to-end encrypted or carrier GSMA-certified.

## Physical release-candidate acceptance

Android and iOS should each pass:

1. Fresh install opens RCS inbox without old password/legacy-account prompts.
2. Device-local signing seed is securely stored; account enroll succeeds against the independent Worker.
3. Copy full SIP address and paste it as a recipient on another device.
4. Send and receive real one-to-one text; test both directions.
5. Restart/reconnect and verify same identity and offline inbox history.
6. Verify SIP WebSocket realtime notifications plus typing and delivered/displayed receipts.
7. Check invalid/foreign SIP handles and network errors show useful messages without account loss.
8. Verify account deletion and any future recovery flow before wider release.
9. Inspect actual screenshots, accessibility, permissions and crash logs on release hardware.

**Current evidence:** Android 16 API36 emulator installed and launched v1.0.4+6, got a new RCS identity, displayed a real incoming server message and sent a synthetic message via Flutter UI that reached a temporary recipient. No physical Android or iPhone acceptance and no current matching IPA have been claimed.

## Submission assets / console work still required

- final screenshots for required phone/tablet form factors;
- app description/subtitle/short description;
- keywords/category selection;
- support URL;
- privacy policy URL;
- account deletion URL in Play Console;
- Apple App Privacy questionnaire;
- Google Play Data Safety form;
- age/content rating questionnaires;
- child-safety declarations/contact where required;
- review notes and test/reviewer account if needed;
- release notes;
- final signed artifacts;
- review buffer before 2026-10-31.

## Release rule

Do not mark Pyre Social store-ready based only on a successful compile. Store-ready means:

- production-compatible backend deployed;
- both signed artifacts produced;
- physical acceptance completed on Android + iPhone;
- public legal/support/deletion URLs live;
- store privacy/safety forms reconciled to the final binary;
- no known P0/P1 account, messaging, notification, deletion, privacy or safety defect remains.
