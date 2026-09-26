# PyreChat Camera Runtime Boundary

## Product rule

PyreChat owns the social product, camera workflow, capture UI, messaging model, identity,
safety controls, storage policy, and visual language.

Third-party AR runtimes are optional rendering providers. They must not define PyreChat's
navigation, friend graph, messaging behavior, account model, or product identity.

## Current runtime

The shipping development path is the native Pyre AR runtime:

- Flutter camera preview/capture
- Google ML Kit face mesh tracking
- Pyre's own smoothing and landmark pipeline
- Pyre built-in lenses and grades
- Pyre custom-lens model and renderer
- Pyre in-app effect creator

This path remains the fallback even after another AR provider is integrated.

## Camera Kit integration boundary

When Snap approves the use case and credentials are available, Camera Kit should be added
behind a native platform adapter on supported mobile targets. The Flutter camera screen
should ask a runtime facade for:

- runtime availability
- initialization state
- effect catalog metadata
- effect activation/deactivation
- rendered camera surface
- capture result
- recoverable error state

The rest of PyreChat must not import or depend on Camera Kit types directly.

## Failure behavior

Camera Kit failure must never make the camera unusable. On initialization failure,
credential rejection, runtime outage, unsupported platform, or revoked availability:

1. stop the Camera Kit session cleanly;
2. fall back to the native Pyre camera;
3. keep capture and messaging available;
4. show a plain-language runtime status if the user needs to know;
5. never discard an already captured local image.

## Compliance guardrails

Before public Camera Kit enablement:

- confirm the submitted PyreChat use case is approved by Snap;
- use required Snap attribution/consent surfaces;
- keep PyreChat branding and UI visibly distinct;
- do not market the integration as Snapchat or imply Snap endorsement;
- do not use Camera Kit data to build PyreChat identity/friend/recommendation profiles;
- keep Snap-provided Lens metadata/binaries inside the retention rules applicable at launch;
- re-review material Camera Kit use-case changes before shipping them.

## Engineering sequence

1. Keep the native runtime green on Windows and mobile.
2. Restore Android/iOS toolchains and verify the existing native Pyre camera.
3. Add the Camera Kit native SDK adapter only after credentials/approval are available.
4. Add runtime conformance tests so both providers obey the same capture contract.
5. Exercise provider failure/fallback paths before enabling Camera Kit for users.
