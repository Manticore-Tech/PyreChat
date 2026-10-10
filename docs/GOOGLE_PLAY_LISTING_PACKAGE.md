# Pyre Social Google Play Listing Package

Status: COPY READY / VISUAL EXPORTS AND DEVICE CAPTURES PENDING  
Prepared: 2026-10-07  
Owner: MantiCore Creative Director  
Product authority: Pyre Social CTO  
Target package: `dev.pyrearms.pyrechat_flutter`  
Target release: `1.0.11+13`

## Truth and claim boundary

This package is based on the current Pyre Social release control sheet and checkpoint.

Allowed claims:

- independent Pyre Social one-to-one RCS-style text messaging;
- self-generated Ed25519 device-bound RCS address; no phone number required;
- exchange full SIP address or short handle to start a conversation;
- persistent offline inbox, typing indicators and delivered/displayed receipts;
- Android app and browser-based Flutter client.

Do not claim:

- carrier RCS/GSMA Universal Profile certification, SMS fallback or telephone-number reachability;
- end-to-end encryption of RCS text; this alpha currently sends ordinary CPIM text through the server;
- cross-device secret recovery, multi-device sync or guaranteed message restore after losing local signing keys;
- group chats, media attachments, camera/Pyre creation, social feeds or legacy username/password login in the RCS-first home screen;
- background push messaging without physical acceptance;
- that the app recovers, bypasses or unlocks any external service's accounts;
- any unverified ranking, installation totals, reviews or store publication.

## Main listing copy — en-US

### App name

Pyre Social

Character count: 11 / 30.

### Short description

Direct messaging with your own Pyre Social RCS address.

### Full description

Pyre Social is a lightweight messenger built around its own independent RCS-style messaging service.

Create a device-owned address, exchange it with a friend and start a direct conversation. Incoming messages are stored for offline retrieval, with typing activity and delivery/read confirmations when clients report them. Android and web clients connect to the same standalone service.

Current alpha features:

- signed Ed25519 device identity with local secure-key storage;
- direct one-to-one text conversations;
- personal RCS address with copy-and-paste sharing;
- offline message history and realtime updates;
- typing and message receipt support;
- no separate legacy password/signup flow.

This is **private Pyre Social messaging**, not carrier-connected phone-number RCS. RCS text is **not end-to-end encrypted** in this alpha. The signing keys belong to the device/browser; key recovery and automatic migration between devices are not ready. Avoid sensitive messages until a reviewed client encryption system is integrated.

Privacy: https://pyre.social/privacy  
Terms: https://pyre.social/terms  
Support: https://pyre.social/support  
Account deletion: https://pyre.social/account/delete

### Suggested category

Communication

Final category selection remains a Play Console configuration decision; it does not authorize console access or publication.

### Release notes — 1.0.4

Fresh RCS-first Pyre Social alpha: create a secure device-owned messaging address, paste a friend's full address, exchange text, and receive messages in realtime or from offline history. Typing and message-receipt support are included. This first-party RCS subset is not carrier-interoperable or end-to-end encrypted.

## Visual direction

Creative concept: **Ember signal**

- Mood: warm, private and resilient; a conversation carried forward rather than a public social feed.
- Palette: deep charcoal/night surfaces with ember orange and warm gold accents already present in the app.
- Core motif: the Pyre flame/mark paired with restrained chat or signal shapes.
- Avoid: Snapchat yellow/ghost cues, third-party logos, fake review badges, ranking claims, lock/bypass imagery, crypto/security shields and any visual suggesting full E2EE.
- UI depictions must come from the current `1.0.11+13` application, not mock screens.

## Google Play visual deliverables

Google's current official requirements were rechecked on 2026-10-07:

- Store icon: 512 x 512, 32-bit PNG with alpha, at most 1024 KB.
- Feature graphic: 1024 x 500, JPEG or 24-bit PNG without alpha.
- Screenshots: at least two; JPEG or 24-bit PNG without alpha; each dimension 320–3840 px, with the long side no more than twice the short side.
- For strong phone promotion eligibility, use at least four 1080 px-or-larger portrait 9:16 captures.
- For tablet presentation, capture at least four truthful 16:9 or 9:16 large-screen images only after the tablet layout passes QA.

Official references:

- https://support.google.com/googleplay/android-developer/answer/9866151
- https://support.google.com/googleplay/android-developer/answer/9859152

### Store icon

Candidate source assets:

- `pyrechat_flutter/assets/app_icon.png`
- `pyrechat_flutter/assets/pyre_logo.png`
- `pyrechat_flutter/assets/pyre_mark.svg`

Required before upload:

1. confirm the chosen source is Pyre Social-owned or has documented rights;
2. export `store/google-play/en-US/icon-512.png`;
3. validate exact dimensions, alpha and file size;
4. visually inspect at small sizes and against light/dark Play surfaces.

The existing files are candidates, not publication-ready evidence until those checks are recorded.

### Feature graphic

Output target: `store/google-play/en-US/feature-graphic-1024x500.png`

Art direction:

- centered ember/flame signal flowing between two restrained chat shapes;
- deep night background with warm orange/gold energy;
- no phone frame, no third-party mark and no unsupported privacy badge;
- no text is preferred, preventing crop and localization problems;
- keep the focal element in the central safe area and edges low-detail.

### Phone screenshot capture plan

Capture **only actual v1.0.11+13 Flutter RCS screens** with temporary first-party test accounts. Do not present legacy photo/video Pyres, username login or privacy shields as current RCS functionality.

| Order | Screen | Evidence | Suggested caption |
| --- | --- | --- | --- |
| 1 | First launch / RCS address | Automatically created owned SIP address | Your address, your connection |
| 2 | RCS inbox | Recent peer conversations in live Flutter UI | Your conversations |
| 3 | RCS chat | Two synthetic users exchange real text | Send directly |
| 4 | Realtime status | Typing or a delivery/read state that actually occurred | Stay in sync |

Screenshot rules:

- Use only synthetic RCS test content; redact any real user conversation, token, signing seed or other private identifier.
- Do not fabricate unsupported features or phone-carrier certification badges.
- Capture raw current-device UI before composing captions; verify against the same submitted APK SHA.

### Tablet screenshot plan

Run the same RCS release candidate on a tablet emulator/device before capturing tablet images. Capture the RCS inbox, address/peer entry, one-to-one thread and current status only after tablet-layout QA. Do not enlarge phone screenshots or depict retired screens.

Proposed output targets:

- `store/google-play/en-US/phone/01-rcs-address.png`
- `store/google-play/en-US/phone/02-rcs-inbox.png`
- `store/google-play/en-US/phone/03-rcs-thread.png`
- `store/google-play/en-US/phone/04-rcs-typing.png`
- `store/google-play/en-US/tablet/01-rcs-inbox.png`
- `store/google-play/en-US/tablet/02-rcs-thread.png`

## Provenance manifest

Create `store/google-play/PROVENANCE.md` with one row per uploaded asset:

| Output | Source | Creator/tool | Rights basis | Capture/build version | Review status |
| --- | --- | --- | --- | --- | --- |

No asset is final until its source, rights basis, dimensions and visual QA are recorded.

## Completion gates

Copy is ready for product/legal review. The listing package is not upload-ready until:

- icon source rights and export validation are recorded;
- feature graphic binary is rendered and validated;
- phone screenshots are captured from the current release candidate;
- tablet screenshots are captured only after large-screen QA;
- Pyre Social CTO confirms every displayed feature matches the submission binary;
- no secret or real-user data appears in captures;
- Play Console forms, account actions, upload and publication remain separately authorized.
## Visual export evidence — 2026-10-07

Brand & Visual Designer produced and binary-validated:

- `store/google-play/en-US/icon-512.png` — 512x512 RGBA PNG, 165,026 bytes.
- `store/google-play/en-US/feature-graphic-1024x500.png` — 1024x500 RGB PNG, 57,265 bytes, no alpha.
- `store/google-play/en-US/VALIDATION.json` — machine-readable export evidence.
- `store/google-play/PROVENANCE.md` — source/rights/review ledger.
- `test/store_visual_export_test.dart` — deterministic generation + validation harness.

Fresh `flutter test --no-pub` passed 95 tests with 1 intentional skip while producing the assets. Binary requirements are satisfied. Upload readiness is still gated on first-party rights confirmation for the canonical source art, human visual review of the PNGs, truthful current-build phone/tablet captures, CTO feature-truth review, and separately authorized Play Console actions.
