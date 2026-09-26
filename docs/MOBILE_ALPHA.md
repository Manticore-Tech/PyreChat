# PyreChat mobile alpha delivery

The active Flutter project is this folder: `PyreChat/pyrechat_flutter`. The parent
`PyreChat` folder also contains a full Flutter SDK checkout and an older nested
app; do not publish either as the app repository.

## Current status

- Canonical GitHub repository: `Manticore-Tech/PyreChat`.
- Android has a verified debug APK and physical-device install/launch.
- iOS release compilation has passed on GitHub's macOS runner.
- iOS face-mesh detection is unavailable because the current ML Kit face-mesh
  plugin has no iOS implementation. The rest of the iOS camera path still needs
  real-device acceptance testing.
- Android notifications currently depend on a live app session; the backend has
  no verified remote push contract. Do not promise delivery while closed.
- This alpha does **not** require a paid Apple Developer Program membership.
  iPhone testers sideload a generated unsigned IPA from a computer and sign it
  with their own Apple ID.

## GitHub Actions alpha artifacts

Every push to `main` and every manual workflow run performs:

1. Flutter dependency restore, analysis, and tests.
2. Android debug APK build.
3. iOS release compile on a GitHub macOS runner with code signing disabled.
4. Packaging of the compiled `Runner.app` into an unsigned IPA suitable for a
   desktop sideloading tool to re-sign for a tester's device.

Download these artifacts from the completed Actions run:

| Artifact | Use |
| --- | --- |
| `pyrechat-android-alpha` | Installable Android debug APK |
| `pyrechat-ios-sideload` | ZIP artifact containing `PyreChat-unsigned.ipa` |

The iOS artifact is intentionally unsigned. A stock iPhone will not install that
IPA directly by tapping it. A tester's desktop sideloading tool signs it for that
specific Apple ID/device during installation.

## Android alpha install

Extract `pyrechat-android-alpha` and install the contained APK. Android debug
builds use the `.dev` application ID suffix so they can coexist with an older
signed PyreChat install when needed.

The debug APK is alpha-only. It is not a Play Store or production release key.

## iPhone alpha install from Windows or macOS

The simplest zero-cost path for testers is a desktop sideloading tool such as
Sideloadly:

1. Download the `pyrechat-ios-sideload` artifact from GitHub Actions.
2. Extract the artifact ZIP to get `PyreChat-unsigned.ipa`.
3. Install Sideloadly on the tester's Windows PC or Mac.
4. Connect the iPhone by USB and trust the computer/device prompts.
5. Drag `PyreChat-unsigned.ipa` into Sideloadly.
6. Select the iPhone and enter the tester's own Apple ID when Sideloadly asks.
7. Start the sideload. Sideloadly re-signs the IPA for that Apple ID/device.
8. On iOS 16 or later, enable Developer Mode under
   **Settings -> Privacy & Security -> Developer Mode** if prompted.
9. If iOS asks to trust the development profile, use
   **Settings -> General -> VPN & Device Management**.

A free Apple account is enough for this development-style install, but Apple's
free Personal Team provisioning expires after 7 days. The tester must re-sign
and reinstall/refresh the app periodically. Apple also limits free Personal Team
usage to 3 installed apps per device, 3 registered devices, and 10 App IDs in a
7-day period.

Sideloadly can automatically refresh apps when its desktop daemon can reach the
device over USB or configured Wi-Fi. This is third-party tooling; testers who
prefer Apple's first-party route can use Xcode on a Mac with a free Personal Team
instead.

## Alpha QA

Test both platforms for:

- signup, login, recovery, and session restore;
- chat send/receive/reconnect;
- camera capture and camera switching;
- photo/camera permissions;
- background/foreground transitions;
- Android notification behavior;
- iOS behavior without ML Kit face-mesh effects.

Do not advertise end-to-end encryption: that is not yet implemented.

## Future store distribution

TestFlight/App Store distribution is intentionally outside the current free
alpha path. It can be added later if the project enrolls in the Apple Developer
Program. The current alpha workflow should stay green without any Apple
distribution certificate, provisioning profile, App Store Connect API key, or
Android production signing key.
