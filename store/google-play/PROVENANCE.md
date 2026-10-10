# Pyre Social Google Play Visual Asset Provenance

Prepared: 2026-10-07  
Worker: Brand & Visual Designer  
Target release: `1.0.11+13`  
Publication status: NOT PUBLISHED

## Asset ledger

| Output | Source | Creator/tool | Rights basis | Capture/build version | Validation | Review status |
| --- | --- | --- | --- | --- | --- | --- |
| `en-US/icon-512.png` | `pyrechat_flutter/assets/app_icon.png` | Brand & Visual Designer via `test/store_visual_export_test.dart` + package:image | Canonical Pyre Social app-owned branding candidate stored in the product repository. Repository search found no third-party logo/reference associated with this asset. Final upload still requires product-owner confirmation of first-party rights because no separate license/assignment document is stored beside the binary. | Pyre Social `1.0.1+3` | PASS: 512x512, RGBA/4-channel PNG, 165,026 bytes (<= 1,048,576) | BINARY READY / RIGHTS CONFIRMATION GATE |
| `en-US/feature-graphic-1024x500.png` | `pyrechat_flutter/assets/pyre_flame.png` + original procedural ember/chat composition | Brand & Visual Designer via `test/store_visual_export_test.dart` + package:image | Uses the canonical Pyre Social flame already shipped by the app plus a new MantiCore-authored procedural composition. No third-party logos, screenshots, review badges, security shields, or platform branding are used. Final upload still requires product-owner confirmation of first-party rights for the flame source because no separate license/assignment document is stored beside the binary. | Pyre Social `1.0.1+3` | PASS: 1024x500, RGB/3-channel PNG, 57,265 bytes, no alpha | BINARY READY / RIGHTS CONFIRMATION GATE |

## Reproducibility and validation

The deterministic export/validation harness is:

`pyrechat_flutter/test/store_visual_export_test.dart`

A successful `flutter test --no-pub` run generated both binaries and validated dimensions, channels/alpha requirements, and the Play icon size ceiling. The machine-readable evidence is:

`pyrechat_flutter/store/google-play/en-US/VALIDATION.json`

The full Flutter regression suite passed during this export: 95 tests passed with 1 intentional skip.

## Visual direction implemented

- deep charcoal/night background;
- ember-orange and warm-gold signal accents;
- centered Pyre flame;
- restrained bilateral chat shapes;
- no text to avoid localization/crop issues;
- no Snapchat/third-party marks;
- no unsupported encryption/security badge;
- no fabricated app UI.

## Remaining gates

1. Product owner / Pyre Social CTO must confirm first-party rights for `assets/app_icon.png` and `assets/pyre_flame.png` before Play upload.
2. Human visual review of the final PNGs is still required because this autonomous pass can validate binary properties but cannot visually inspect the Windows-hosted files through the current bridge.
3. Phone/tablet screenshots remain a truthful device-capture gate and must come from the current `1.0.3+5` app with synthetic data only.
4. Play Console access, upload and publication remain separately authorized actions.
