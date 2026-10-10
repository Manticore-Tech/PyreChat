# PyreChat mobile alpha delivery

Canonical app source: `PyreChat/pyrechat_flutter`.

Canonical GitHub repository: `Manticore-Tech/PyreChat`.

The parent `PyreChat` workspace also contains backend code, a Flutter SDK checkout,
and an older nested app copy. Do not publish those as the mobile app repository.

## Current verified state

- Flutter analyze/test lane is green locally.
- Android package identity is `dev.pyrearms.pyrechat_flutter` for all current builds.
- Android background FCM delivery is physically verified on the canonical package.
- Android debug APK build/install/launch is physically verified.
- iOS release compilation has previously passed on GitHub macOS runners.
- iOS Keychain secure storage and native Firebase Messaging/APNs wiring are staged.
- iOS Firebase/push, Camera Kit, camera, and media behavior still need Xcode 26 + real-device acceptance.
- Android remains the physically verified runtime; both Android and iOS are store targets for October 2026.

## Workflow

Workflow file:

`.github/workflows/mobile-alpha.yml`

### Pull requests

PRs run:

1. `flutter pub get`
2. `flutter analyze --no-pub`
3. `flutter test --no-pub`
4. Android **debug** APK compile without repository signing/Firebase secrets
5. iOS release compile without signing
6. unsigned iOS IPA packaging

PRs do not publish website artifacts.

### Pushes to main/master

Mainline alpha runs require:

- stable Android signing credentials;
- Firebase Android configuration;
- Firebase iOS configuration for iOS notification builds.

They produce:

- stable-signed Android **release** APK;
- Google Play **AAB**;
- unsigned iOS IPA suitable for desktop re-sign/sideload;
- optional website publication to the PyreChat R2 app paths when Cloudflare
  credentials are configured.

The workflow intentionally fails a main/manual Android alpha build instead of
silently publishing an APK signed by a disposable CI debug key.

### Manual workflow runs

`workflow_dispatch` currently exposes:

- **Build Apple-distribution-signed iOS IPA**
- **Enable Camera Kit in this manually triggered alpha build**

Camera Kit is off for ordinary push/PR builds. A manual Camera Kit test run only
activates it when the explicit checkbox is enabled and both Camera Kit secrets are
present.

The Pyre-native camera remains the default/fallback.

## GitHub Actions configuration

### Android alpha signing secrets

Required for push/manual Android release builds:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

`ANDROID_KEYSTORE_BASE64` is the complete stable Android alpha JKS/keystore,
base64-encoded as one GitHub Actions secret.

Do not rotate this key casually. Testers must receive future APKs signed by the
same key for in-place updates to work.

### Firebase Android secret

Required for push/manual Android release builds:

- `FIREBASE_ANDROID_GOOGLE_SERVICES_JSON`

The workflow verifies that the injected Firebase config contains:

`dev.pyrearms.pyrechat_flutter`

This prevents another package/FCM mismatch.

### Firebase iOS secret

Required for non-PR iOS alpha/store builds:

- `FIREBASE_IOS_GOOGLE_SERVICE_INFO_PLIST`

Store the complete Firebase `GoogleService-Info.plist` contents in that secret.
The workflow writes it to the ignored `ios/Runner/GoogleService-Info.plist` path
and verifies its `BUNDLE_ID` is:

`dev.pyrearms.pyrechatFlutter`

Pull requests copy the committed placeholder example only for compile validation.
The placeholder must never be used for a distributable build.

The Firebase iOS app must have APNs configured in Firebase, and signed store
provisioning must include the Push Notifications entitlement.

### Camera Kit secrets

Only used when a manual run enables Camera Kit:

- `CAMERA_KIT_API_TOKEN`
- `CAMERA_KIT_LENS_GROUP_IDS`

The workflow then writes the ignored platform-local config with
`CAMERA_KIT_INTERNAL_EVAL=true`.

Do not commit Camera Kit tokens or Lens Group credentials into source control.

### Optional website artifact publication

- secret: `CLOUDFLARE_API_TOKEN`
- repository variable: `CLOUDFLARE_ACCOUNT_ID`

When configured, non-PR runs publish:

- Android APK -> `pyrechat-media/app/pyrechat.apk`
- unsigned iOS IPA -> `pyrechat-media/app/pyrechat.ipa`

If Cloudflare credentials are absent, the workflow still keeps the GitHub Actions
artifacts and skips website publication.

### Optional signed iOS IPA

Used only when the manual **Build Apple-distribution-signed iOS IPA** option is
enabled:

- `IOS_DISTRIBUTION_CERT_P12_BASE64`
- `IOS_DISTRIBUTION_CERT_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_TEAM_ID`

This path requires Apple Developer Program distribution credentials. The
workflow imports a temporary keychain, verifies the provisioning profile
matches `dev.pyrearms.pyrechatFlutter` and includes production Push Notifications
(`aps-environment=production`), archives the app, exports the IPA, verifies its
signature, uploads the artifact, and deletes the temporary keychain.

It does not currently upload to App Store Connect/TestFlight.

## Artifacts

| Artifact | Contents |
| --- | --- |
| `pyrechat-android-alpha` | Android APK; debug on PRs, stable-signed release on main/manual runs |
| `pyrechat-android-play` | Stable-signed Google Play AAB from non-PR Android builds |
| `pyrechat-ios-sideload` | `PyreChat-unsigned.ipa` for desktop re-sign/sideload |
| `pyrechat-ios-signed` | Paid-Developer-Program signed distribution IPA from the optional manual signed-iOS job |

## iPhone sideload alpha without a paid Apple Developer account

The immediate tester path is the existing `PyreChat-unsigned.ipa` plus
Sideloadly on Windows or macOS.

Sideloadly can use an ordinary free Apple ID to provision and install the app on
a stock iPhone. Free provisioning expires after 7 days. Sideloadly's automatic
refresh can re-sign before expiry when its computer can see the iPhone over USB
or previously configured Wi-Fi pairing.

For a local buddy test, the tester iPhone can be connected to the operator's PC
once and provisioned there; the tester does not need to manually sign the IPA.
For a remote tester, the practical free path is for the tester to run Sideloadly
on their own computer, load the unsigned IPA, and use their own free Apple ID.

Do not treat a free-signed iOS build as proof that APNs works. Apple controls
the `aps-environment` entitlement through the provisioning profile, and the
paid Apple Developer Program remains the intended path for full Push
Notifications entitlement and production/TestFlight distribution testing.

## Alpha QA

At minimum test:

- signup, login, recovery, and session restore;
- username/display-name editing once the matching backend route is deployed;
- chat send/receive/reconnect;
- offline queued send + reconnect + restart;
- camera capture and camera switching;
- Camera Kit render/capture when intentionally enabled;
- background/foreground transitions;
- Android background notification delivery;
- notification tap opening the correct conversation with the fresh message;
- iOS FCM/APNs token registration, background delivery, and notification tap routing;
- iOS Keychain persistence after restart;
- iOS behavior on real hardware.

Do not advertise end-to-end encryption yet. The current private-message transport
is still a development baseline pending the reviewed E2EE data-plane replacement.
