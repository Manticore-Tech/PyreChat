# PyreChat mobile alpha delivery

The active Flutter project is this folder: `PyreChat/pyrechat_flutter`. The parent
`PyreChat` folder also contains a full Flutter SDK checkout and an older nested
app; do not publish either as the app repository.

## Current status

- Android has a verified local debug APK and physical-device install/launch.
- iOS has source and a 15.6 deployment target, but has not been compiled on macOS
  or tested on an iPhone yet.
- The folder is not currently a Git repository. GitHub Actions will only start
  after this **active app folder** is pushed to a GitHub repository.
- The ML Kit face-mesh plugin only implements detection on Android. The iOS
  camera must work without that feature in this alpha; verify it on an iPhone.
- Android notifications currently depend on a live app session; the backend
  has no verified remote push contract. Do not promise delivery while closed.

## 1. Put the active app on GitHub

Create an empty **private** GitHub repository for the app. From
`E:\Documents\Minecraft Modding\Projects\PyreChat\pyrechat_flutter`:

```powershell
git init
git branch -M main
git add .
git status --short
git commit -m "Set up PyreChat mobile alpha"
git remote add origin https://github.com/OWNER/REPOSITORY.git
git push -u origin main
```

Review `git status --short` before committing. Do not include
`android/local.properties`, credentials, build output, `qa_snapshots`,
or the nested legacy app. The `.gitignore` excludes these. If you have an
existing upstream app repository, use that repository instead of making a
second source of truth.

A push or pull request runs Flutter analysis/tests, an Android development APK
build, and an unsigned iOS release compile on a GitHub macOS runner. A passing
iOS compile proves build compatibility, not signing or device behavior.

## 2. Android alpha signing

Create or reuse **one stable Android upload keystore**. Keep its original
securely backed up: changing it breaks in-place upgrades of the same package.
Use `keytool -genkeypair -v -keystore pyrechat-alpha.jks -alias pyrechat-alpha
-keyalg RSA -keysize 3072 -validity 10000` and enter passwords at its prompts
if you do not already have one. Never commit the keystore or passwords.

Add these GitHub repository Actions secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 bytes of the .jks file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | Alias/private-key password |

On PowerShell, get a keystore file's base64 with
`[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\secure\pyrechat-alpha.jks"))`.
Store it directly as a GitHub secret, not in this repo or chat.

The manual alpha workflow builds a signed
`dev.pyrearms.pyrechat_flutter` release APK. Download the
`pyrechat-android-alpha` artifact from the Actions run and install it on
test devices. This package may conflict with an earlier installation signed
by another key; preserve that app's data before replacing it. Ordinary
push builds are debug APKs with the separate `.dev` package and are for CI
checks, not repeatable alpha upgrades.

## 3. Apple/TestFlight signing

Apple's Developer Program, an App Store Connect app record, and the following
assets are required for the iOS alpha:

1. Register the explicit iOS Bundle ID `dev.pyrearms.pyrechatFlutter` on
   the Apple team; create the app record with that exact ID in App Store Connect.
2. Create an Apple Distribution certificate and export its certificate **and
   private key** to a password-protected .p12 file.
3. Create an **App Store** distribution provisioning profile for that Bundle ID,
   team, and certificate; download the .mobileprovision file.
4. Create an App Store Connect API key with rights to upload builds. Keep the
   one-time .p8 download, Key ID, and Issuer ID.

Add these Actions secrets:

| Secret | Value |
| --- | --- |
| `IOS_DISTRIBUTION_P12_BASE64` | Base64 bytes of the exported .p12 |
| `IOS_DISTRIBUTION_P12_PASSWORD` | Export password |
| `IOS_APPSTORE_PROFILE_BASE64` | Base64 bytes of App Store .mobileprovision |
| `APPLE_TEAM_ID` | 10-character Apple Developer team ID |
| `APPSTORE_KEY_P8_BASE64` | Base64 bytes of App Store Connect .p8 |
| `APPSTORE_KEY_ID` | App Store Connect API Key ID |
| `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID |

Base64 encode binary files as in the Android example. The profile must be an
App Store distribution profile, not a development or ad-hoc profile. The
workflow installs the signing assets only into its temporary macOS runner,
builds an IPA, uploads it with Apple's `altool`, and removes local copies.

## 4. Run the release and invite testers

In GitHub, open **Actions → PyreChat mobile alpha → Run workflow** on
`main`, and enable `publish_alpha`. The checks and unsigned iOS compile
must pass first. The Android signed APK is saved as an Actions artifact; iOS
is uploaded to App Store Connect for TestFlight processing. Each run uses a
fresh build number.

Add internal testers in App Store Connect. External testers may require beta
app review before they can install. Test both devices for signup/recovery,
session restore, chat/reconnect, image capture, permissions, backgrounds and
camera switching before widening the alpha. iOS face-mesh effects are not
available with the current plugin. Do not advertise end-to-end encryption:
that is not yet implemented.

If the first macOS build exposes a platform or dependency error, use the
Actions log to repair it; no iOS build has yet been run from this workstation.

