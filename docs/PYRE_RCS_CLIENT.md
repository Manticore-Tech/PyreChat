# PyreSocial RCS — Flutter frontend integration

Updated: 2026-10-09
Implementation scope: canonical `PyreChat/pyrechat_flutter/`, Android/iOS/Flutter web.
No external publication or account/security settings changed.

## Code and user navigation

- `lib/services/pyre_rcs.dart` — `PyreRcsProtocol`, `PyreRcsClient`, `PyreRcsMessage`, direct-worker HTTP/SIP WebSocket transport.
- `lib/screens/chats/pyre_rcs_screen.dart` — RCS inbox, address copy, peer handle entry, recent conversations, direct 1:1 thread composer, recipient delivery/read receipts and live typing indication.
- `lib/screens/chats/chats_screen.dart` — an accessible **RCS messages** control in the Chats header launches the RCS inbox. The older chat list remains available while identity/E2EE migration is unresolved.
- `pubspec.yaml` and lockfile — `cryptography` 2.9.x for cross-platform Ed25519; existing `SecureBlobStore` provides Android Keystore, iOS Keychain and WebCrypto-backed browser secret storage.
- `test/pyre_rcs_test.dart` — CPIM/IMDN, Ed25519 signatures, unsigned payload prevention, closed enrollment identity retention, direct HTTP contract, status and typing.
- `test/pyre_rcs_screen_test.dart` — RCS inbox to real screen navigation and injected transport send smoke.

## RCS identity lifecycle

1. The client creates a **random, device-local RCS address** (`r` plus 24 hex characters) and Ed25519 signing seed. It stores the secret key in the platform's secure store, namespaced by the signed-in Pyre Social user ID. Plaintext `SharedPreferences` and browser localStorage are not allowed fallbacks.
2. Enrollment: `POST https://messages.pyre.social/v1/identity/challenge` intent `enroll`; sign the exact `pyresocial-rcs-v1\nenroll\nsip:<handle>@messages.pyre.social\n<nonce>` UTF-8 challenge; `POST /v1/identity/enroll` with public key, signature and nonce. Retain the same keypair and handle if the server returns `403 Enrollment temporarily closed`.
3. Subsequent login: signed `session` challenge; 7-day opaque bearer session persisted in secure storage.
4. `GET /v1/rcs/messages` page-history, `POST /v1/rcs/messages` to send CPIM, `GET /v1/rcs/status` to show Sent (sender outbox), Delivered (recipient mailbox durable store), and Read (verified visible conversation `displayed` IMDN).
5. Incoming device receipt is separate telemetry after authenticated exact-message fetch. Opening a foreground visible conversation sends `displayed` IMDN automatically; merely storing on the server, waking with FCM, or viewing the inbox never marks Read.
6. Realtime: bearer-authenticated `/v1/rcs/socket-ticket`, then `wss://messages.pyre.social/v1/sip?handle=<handle>&ticket=<ticket>` with WebSocket subprotocol `sip`. Send SIP REGISTER on success; subscribe to incoming SIP MESSAGE CPIM and typing events, refresh durable history on event/reconnection.
7. Typing: rate-limited client CPIM `application/im-iscomposing+xml` active/idle. Peer sees a short-lived typing indicator.

This is **direct communication between Flutter and the ONE separate RCS Cloudflare Worker**. No Twilio, no parallel Worker, and no request through `pyrechat` for the RCS send/receive path. The normal Pyre Social auth session is used only to enter the app; the RCS Worker maintains its separate cryptographically proven address ownership.

## Honest limits

- The Worker still has `ENROLLMENT_ENABLED=0`; new accounts cannot be provisioned until an explicitly authorized server-side account/security policy change. The RCS screen explains this error and allows retry without regenerating keys. **This is not a two-device live acceptance yet.**
- A Pyre Social username is **not** the same as a securely owned SIP handle. We generate a random RCS address rather than letting an arbitrary signed-in client impersonate a desired Pyre username. The operator can share the device RCS address with a buddy; verified linking/discovery must be separately designed before automatic takeover of legacy chats.
- RCS `text/plain` is **not E2EE**. The UI states it plainly. The new Worker can store opaque MLS envelopes, but this frontend does not yet carry out cross-device MLS key exchange on the RCS path; it must not claim private encryption. Existing MLS chat handling stays on the legacy transport while migrating.
- Group CPM/MSRP, RCS HTTP media transfer, verified telephone-number identity, SIP/IMS carrier interop, push-notification wakeup and cross-device RCS key recovery are not implemented.
- Flutter web and Android must be built and deployed separately from the RCS Worker; website direct-download APK/IPA publication remains an independent release task.

## Validation / QA evidence

Recorded during this implementation pass:
- `flutter pub get` PASS with the `cryptography` package resolved.
- Flutter static analysis PASS with 0 issues.
- First end-to-end test run: 195 Flutter tests PASS; final added SIP REGISTER and screen tests: 197 PASS.
- Final QA plan `pyresocial-rcs-flutter-native-web-build-20261009`: Flutter web release build PASS (JS output; WASM dry-run emitted preexisting flutter_rust_bridge compatibility warnings), and Android release APK PASS: `build/app/outputs/flutter-apk/app-release.apk`, 223,625,586 bytes, SHA-256 `093bd765ab9ca1ec9661318c0754549ab2e31038b20983635a6aa60a6ccdcc39`.
- No physical phone/equipment was connected during initial implementation; a production `GET /health` and WSS handshake with two real RCS accounts remain external acceptance gates.

**Do not advertise the native RCS interface as fully live for new users until authenticated two-account messaging passes against the independently hosted Worker and the owner-approved enrollment policy is enabled.**

## Live production cutover — 2026-10-09

- Owner authorized RCS-only fresh start. Flutter `lib/main.dart` now starts directly at `PyreRcsInboxScreen` instead of legacy Pyre Social login. For new installs, the secure RCS key namespace uses `pyresocial-rcs-primary-v1`, independent of old account IDs.
- Cloudflare standalone RCS Worker `12f923b0-356d-4d4b-bfc6-3d1ea8a88658` now has enrollment **enabled** and was independently verified with two temporary real accounts (Ed25519 challenge, CPIM send/history, IMDN delivery, SIP WSS 200 and realtime inbound push).
- Production Pyre Social Flutter web at `https://pyre.social/app/` deployed in website Worker version `2c48120b-800d-4814-aec9-ded4593d885c`. Website CSP allows direct `https://messages.pyre.social` and `wss://messages.pyre.social`; site redirects legacy login and denies old auth POST routes.
- Old D1 account/media rows were not deleted: platform safety denied a bounded D1 inventory. API login/signup retirement and RCS independence are in effect. Mobile APK update has separate build/publication evidence. RCS plaintext text is **not** E2EE and is **not** carrier RCS; do not claim otherwise.

## Historical Android native background-delivery source phase (superseded by live v1.0.6 release)

- Native Android RCS FCM/JobScheduler receive path added, kept separate from the existing cross-platform SIP/WebSocket and CPIM code. Flutter registers an FCM token after authenticated RCS startup/resume and saves a single device-delivery-only credential encrypted using AndroidKeyStore. Native FirebaseMessagingService receives a content-free FCM wake even if Flutter UI was closed (except force-stop), fetches the exact CPIM over HTTPS, stores it encrypted locally, and then sends server-verified delivered IMDN; displayed remains a separate explicit user action.
- The Material 3 RCS inbox also sends delivered IMDN when the inbox (without a thread open) actually fetches incoming history. The peer and ID are used together to deduplicate.
- Node RCS backend protocol+push tests: 13 PASS. Flutter full suite including 3 registration mocks: 202 PASS + 1 skip. Analyzer 0 issues. Android Kotlin debug APK compiled successfully. All tests were against source/mocks, not live FCM notifications.
- **Superseded architecture (do not follow the old secret instruction):** The private Cloudflare service binding `FIREBASE_PUSH_GATEWAY` now uses the existing Firebase credential on the separate `pyrechat` Worker. RCS holds no Firebase key. v1.0.6+8 with native receipt service is publicly deployed. Tests prove storage/scoped receipt semantics, but real FCM notification on a closed Android phone is still awaiting physical acceptance. Never mark delivered for a mere push/server acceptance.
- Source/testing/activation details live in PyreSocialMessaging/docs/BACKGROUND_DELIVERY.md. Safari/browser closed state is a different future web push feature; this slice is Android native only.


## 2026-10-09 Firebase RPC architecture — current

The owner approved reusing existing Firebase infrastructure while preserving the standalone RCS Worker. Older statements above claiming a new RCS-owned Firebase service-account secret is required are **SUPERSEDED**. \`pyrechat\` Cloudflare Worker keeps the existing Firebase credential and now exports only the private named entrypoint \`RcsFirebaseGateway\`. \`pyresocial-messaging\` has the optional \`FIREBASE_PUSH_GATEWAY\` private service binding to that entrypoint; it does not receive the credential or Google token and keeps independently durable RCS messaging.

- Production \`pyrechat\` gateway deploy version \`acade2d7-960b-4551-b7a6-414356e33c74\` (site/web routes healthy).
- Production standalone RCS binding deploy version \`7999256e-b1f2-4bca-ad0b-025e8e7f6d91\` (13 tests). Production two-temp-account smoke passed authenticated device registration, exact CPIM device fetch and verified IMDN delivered; no real Google FCM token was used, so actual closed-app notification delivery is **not** verified.
- Canonical v1.0.6+8 Android Flutter native background-receive APK builds PASS, 214182282 bytes SHA256 \`5f2d9fd648a74e250843846607f1d99f25bc664ff4f8c56f5e72136f4027a64e\`; full Flutter 203 PASS (+1 skip) and analyzer 0 issues. Website static 13-piece stage/reassembly PASS. Publication awaits same-run production HTTP/byte verification.
- Standalone RCS messages remain plain text (not E2EE), not carrier IMS, and no Pyre Number Registry changes. A real on-device closed-app notification and delivered status remain the final acceptance test.
- Canonical background delivery contract: PyreSocialMessaging/docs/BACKGROUND_DELIVERY.md.


## 2026-10-10 — Private Firebase module + Android v1.0.6+8: production release verified

- Backend: independent pyresocial-messaging Worker version 7999256e-b1f2-4bca-ad0b-025e8e7f6d91, with private FIREBASE_PUSH_GATEWAY binding to existing pyrechat#RcsFirebaseGateway; Firebase service-account JSON remains exclusively on pyrechat, with no duplicate key. Live owner-authorized two-account QA verified HTTPS, SIP WSS, durable offline CPIM, authenticated device registration, exact device-scoped CPIM receive, delivered IMDN progression and QA account cleanup. Synthetic token used; real FCM acceptance not yet verified.
- Website/public Android: pyrechat Worker version b364d1cf-80a3-4eb7-ab69-702a2722d021 successfully deployed v1.0.6+8 Flutter RCS and native Android background receiver. /api/download/android-rcs responds 307, no-store, to immutable https://pyre.social/api/download/android-rcs-v1068 (HTTP 200, PyreSocial-RCS-1.0.6.apk). Old v1.0.5 v1057 immutable route remains 200 for rollback. Public APK full GET SHA-256 independently verified for all 214182282 bytes: 5f2d9fd648a74e250843846607f1d99f25bc664ff4f8c56f5e72136f4027a64e. Local 13 static parts also fully reassembled and matched.
- Flutter analyze passed 0 issues; Flutter suite 203 pass + one skip; RCS 13/13 Node tests passed; website security/TypeScript/Vite checks passed. Emulator-5554 Android 16: installed rebuilt debug APK 1.0.6+8 preserving existing emulator data and launched into working RCS Messages inbox. The emulator has Google Play Services but FCM cannot register there because the installed GMS version 252635038 is below the SDK-required 261200000; no FCM token or encrypted device delivery grant was present. No credential values were read. Therefore emulator QA DOES NOT prove background FCM.
- Remaining Android background-delivery operational acceptance: install official v1.0.6+8 on a physical Google Play Services-compatible phone, launch once with notifications allowed, then swipe the app closed (not Android force-stop); send from second web identity and verify delivered plus generic notification without opening Flutter UI. Verify displayed only after opening. Test two rapid messages, lock, temporary offline, battery saver. Android cannot guarantee immediate delivery in force-stop/Doze/disconnection cases. Browser-only closed-tab push is a separate future module.
- No changes to canonical SIP/CPIM/IMDN message transport, account rows, number registry, private Firebase credentials or account security. Firebase-only wake remains optional and failure must never block RCS durable message storage. Product remains not E2EE/carrier-certified RCS.
## 2026-10-09 owner-selected public statuses + Android preview settings (local source pass)

- Public status now follows Sent (sender Durable Object outbox), Delivered (recipient account mailbox durability), Read (verified `displayed` IMDN from a visible thread). Device `delivered` IMDN remains a separate diagnostic; it does not gate Delivered. Legacy `server-accepted` is compatible as Delivered.
- The RCS inbox renders Sent/Delivered/Read and exposes **Notification settings** on Android. **Show message previews** defaults on; toggling off persists a per-device Android SharedPreferences boolean via the existing native notification MethodChannel. The toggle never unregisters FCM or prevents messaging.
- Kotlin decrypts the exact CPIM already saved in private AndroidKeystore-encrypted storage to obtain a short preview of `text/plain` content. If not fetched, opted out, quiet mode/OS permission blocks alerts, or content is encrypted opaque MIME, a generic New message notification is used (or no alert according to OS/user preference). **No message body is included in the FCM wake.**
- **Source validation (no production release in this pass):** Flutter analyze clean; 205 tests PASS + one intentional skip; Android debug APK compilation PASS (353860228 bytes); standalone RCS Node 14/14 PASS. A physical closed-app FCM acceptance test on a Play Services-compatible Android phone is still pending. iOS/APNs parity remains separate.
## 2026-10-09 Android 1.0.8+10 direct website release — LIVE

Owner-authorized independent RCS Worker `3cdf0660-d025-49fa-b121-61963b8a8033` and updated website Worker `6a5c27e2-b5c4-4bc8-8f60-d2400bc118e2` were deployed. The public Android APK is served as immutable `https://pyre.social/api/download/android-rcs-v10810`; alias `/api/download/android-rcs` redirects there. Verified public HTTP HEAD 200, length **214673902**, SHA-256 header `76e7bd11686a906e874420d685bf8f424153112eb25efa6bab9c7a28167f94b1`, matching signed release and independent locally SHA-checked 13 static chunks. Previous immutable v1.0.7, v1.0.6 and v1.0.5 URLs remain served intact. Website security/build, Flutter 205-test suite, analyzer and signed Android release build PASSED.

This shipping APK includes server-mailbox Delivered, verified foreground Read, Android Firebase notifications, and a local message preview toggle enabled by default. The private FCM wake still carries no text. It is **not yet physically validated** for closed-app FCM callback or previews on a real Android phone. Install over existing PyreSocial APK to preserve Android Keystore-backed RCS identity.

## 2026-10-09 RCS notification regression correction (unreleased)

Owner reports no Android notifications in public 1.0.8+10 whereas pre-alpha notifications worked. Identified a real native presentation race: the RCS FCM data-only callback attempted bounded authenticated HTTPS CPIM fetch before posting an Android alert. Staged a source-only fix in `PyreFirebaseMessagingService.kt`: validate first-party wake identifiers; post a generic notification **first**; then attempt exact CPIM fetch, secure local storage, and delivery acknowledgment; update the **same ID** with a decrypted short preview if available/previews enabled, with `setOnlyAlertOnce` to prevent double sounds. Content-free Firebase transport retained. Focused `test/pyre_rcs_native_notification_contract_test.dart` added. Flutter 207 tests (+1 intentional skip) PASS, analyzer PASS, Android native debug build PASS.

**NOT YET RELEASED to the website.** Actual phone's RCS registration/provider wake and Android notification permission status are unknown; the only connected ADB device is an emulator without functional modern FCM. In public 1.0.8+10, open the top-right RCS account/address sheet and inspect `Android background delivery` (`Server: device registered`, `Last Firebase wake`) before attributing all failures to the presentation race. Do not uninstall, clear app data, or reset the RCS Keystore identity during diagnosis.

## 2026-10-10 FCM reserved sender field correction — source only

Physical Android v1.0.8+10 screenshot shows no active server device registration and `Last Firebase wake: invalid`. Found `PyreChat/worker/lib/rcs-firebase-gateway.ts` sent Firebase data key `from` (reserved by Google) and interpreted HTTP 400 `INVALID_ARGUMENT` as bad device token, deleting the registration for malformed payload. Source correction: FCM now transports `sender` (RCS internal envelope retains `from`); Android native receiver translates `sender` to internal `from` before secure CPIM fetch, preserving pre-alpha notification branch. Gateway deletes only explicitly invalid FCM tokens, not arbitrary request errors. The independent source fix from the prior pass also displays a safe generic alert before native HTTPS fetch and later updates same ID with optional local preview. Token refresh recovery belongs to claim `pyresocial-rcs-receipts-background-qa-20261010` and workforce request `WR-20261010-002`.

**Do not deploy only the gateway:** released 1.0.8+10 Android receiver needs the updated `sender` handling. Ship version-incremented Android + private Firebase gateway in a coordinated owner-approved release; run physical device push registration + closed-app acceptance and preserve Keystore/data. Tests and release truth are tracked in ManticoreCodeBridge/PYRECHAT/LAST_HANDOFF.md.

## 2026-10-10 public Android v1.0.9+11 + private Firebase gateway live

Owner explicitly authorized v1.0.9 publication. Public official [Android download](https://pyre.social/api/download/android-rcs-v10911) is HTTP 200, 214673902 bytes, SHA-256 `6633107b85b84368bd40c3d7d35e59f77d66ea66e7cc94fde16b901c6dbc9834`. Unversioned official URL redirects HTTP 307 to the new immutable release. Older `v10810`, `v1079`, `v1068`, `v1057` preserved. Production website Worker `pyrechat` version `6187dca5-d914-41d7-b83e-8dfcdac0c226` also activates corrected private Firebase gateway. No Play Store update or Firebase credential mutation.

Included: FCM data reserved-key regression `from` -> `sender` plus native compatible internal mapping; reject only explicit bad-device-token errors rather than generic invalid-request; generic notification before potentially slow HTTPS fetch; optional locally decrypted preview updates same notification without extra alert. Signed Android release build and 207 Flutter tests PASS; site QA/deploy and public HEAD PASS. **Not claimed**: real physical phone closed-app FCM arrival or previews. Install over existing APK, launch and allow registration, then inspect server push registration and send controlled new message. Do not uninstall or clear data. Automatic token-recovery follow-up `WR-20261010-002`.
