# Pyre Social Google Play Data Safety Draft

Status: SOURCE-DERIVED DRAFT / FINAL SDK REVIEW REQUIRED
Prepared: 2026-10-07
Package: `dev.pyrearms.pyrechat_flutter`
Release: `1.0.11+13`

Official Google references rechecked for this release pass:
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://support.google.com/googleplay/android-developer/answer/18258653

## Source-derived release truth — RCS-first alpha

- The Flutter v1.0.4+6 home screen now starts directly in the separate RCS client, not the retired legacy password signup.
- Each device creates a random SIP address and Ed25519 keypair; the private signing seed remains in secure local storage and is not uploaded. The server stores the public key and session-token hashes.
- New RCS text messages are **not end-to-end encrypted**. The separate Cloudflare Worker receives CPIM text, sender/recipient address, timestamps and delivery/read status, stores message history, and forwards it to recipients.
- A user's account can currently be deleted by an authenticated Worker API; a matching visible in-app RCS deletion flow still needs implementation before general store release. Public information is available at https://pyre.social/account/delete.
- Legacy PyreChat D1/R2 account/media data have **not been purged**, even though old public signup/login routes are retired. Disclosures must account for retained historical user data where applicable.
- The Android binary still contains Firebase, camera/ML and optional Camera Kit SDK surface from the earlier app; current RCS UI does not mean those SDKs or manifest permissions are absent. The Android manifest does not request location, contacts, SMS/call logs, broad storage management or broad installed-app inventory.

## Candidate Play data categories

| Category | Current RCS-first use | Required? |
| --- | --- | --- |
| Public account/address data | Random SIP handle and Ed25519 public key | Required for messaging |
| Authentication/security data | Challenge proofs, session-token hashes and rate-limit metadata | Required for secure service |
| Messages | Plaintext CPIM message body, peer addresses, timestamps, message status | User-created |
| Device/app identifiers | Device-local key store; existing compiled Firebase/native dependencies need audit | Varies by enabled SDK |
| Diagnostics/activity | Cloudflare Worker operational data and any enabled first-party diagnostics | Service operation |
| Retired legacy data | Historical user accounts, optional uploaded media, session records still resident in old D1/R2 | Historical retention/purge review |
## Third-party review gate

Do not lock the Play Console "shared" answer until the exact submission AAB is reviewed against current provider disclosures for:

1. Firebase Cloud Messaging.
2. Cloudflare Worker/D1/R2/Analytics infrastructure.
3. Google ML Kit face-mesh dependencies.
4. Camera Kit, which the normal release workflow leaves disabled unless explicitly enabled for a manual build.
5. Any additional transitive Android SDK present in the final AAB.

The final Data safety answers must match the submitted binary and live privacy policy. Provider/service-processor handling must be classified using Google's current Data safety definitions rather than guessed from source ownership.

## Related Play declarations still required

- Data safety form.
- Privacy-policy URL.
- Account-deletion URL.
- Target-audience / age declaration.
- Content rating.
- Ads declaration.
- App-access instructions for review if needed.
- Permission-specific declarations requested for the submitted AAB.
- Closed-testing configuration, testers, release notes, and truthful current-build screenshots.

The previous password/signup flow enforced a 13+ age floor, but the **new RCS-first enrollment flow currently has no age-gate UI**. Age/child-safety policy and Play target-audience declarations require explicit review before broad release.

## Exact next gate

Before the Data safety form is considered complete:

1. build the stable-signed AAB intended for upload;
2. inspect its final SDK/dependency surface and Camera Kit state;
3. reconcile each Play data type against provider disclosures;
4. cross-check the live privacy policy;
5. enter the answers in Play Console;
6. compare the generated public Data safety preview against this document;
7. preserve dated release evidence.

Until those checks pass, this is a source-derived draft, not a completed Play Console declaration.
