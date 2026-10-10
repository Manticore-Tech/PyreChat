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


## 2026-09-26 Camera Kit integration decision

Current Snap Camera Kit terms were re-reviewed against the live 2026 terms. The old recovered
PyreChat README contains a historical blanket statement that Camera Kit could not be used by a
visual messenger. The current Camera Kit terms reviewed for this pass do **not** contain that old
blanket wording. They do, however, require approval/re-review of the submitted use case, prohibit
using Camera Kit to imitate Snapchat/Snapchat Cam/Spectacles, require Snap branding and affirmative
user agreement to Snap's Terms/Privacy Policy before Camera Kit access, require appropriate Lens
compliance, and require Creative Kit to include Snapchat as an early sharing option when Camera
Kit content can be shared out to other platforms.

The canonical Flutter integration should follow Snap's own Flutter sample architecture rather than
trying to pipe Camera Kit through Flutter's existing `camera` plugin:

### Android

- Change the Flutter host activity to `FlutterFragmentActivity` because Snap's sample registers an
  Activity Result contract.
- Add Snap's `com.snap.camerakit:support-camera-activity` dependency at the current approved SDK
  version.
- Register `CameraActivity.Capture`.
- Launch `CameraActivity.Configuration.WithLenses` with the Camera Kit API token and one or more
  Lens Group IDs.
- Return the captured image/video file path and media type through a MethodChannel.
- Suspend/release the native Pyre `CameraController` before launching Camera Kit, then reacquire
  it on return.
- Treat cancellation, authorization failure, unsupported device, or Camera Kit runtime failure as
  a clean fallback to the native Pyre camera.

### iOS

Snap's official Flutter sample uses the same boundary: Flutter invokes a MethodChannel, native iOS
opens a `FlutterCameraViewController` backed by Camera Kit, and the captured file path is returned
to Flutter. The existing GitHub macOS/iOS compile lane should be used to verify the adapter before
any TestFlight enablement.

### Credentials / configuration

- API token and Lens Group IDs stay outside source control.
- Do not reuse or print historical Camera Kit credentials merely because an old local Capacitor
  tree contains them.
- The current Flutter package identity must be authorized for the Camera Kit token; Camera Kit can
  reject an unauthorized package/token combination.
- Camera Kit's current Android API accepts an explicit API token and the iOS session config accepts
  an explicit API token; legacy application-ID authentication is deprecated.
- Public Camera Kit enablement remains off until the PyreChat use case and current mobile package
  identities are approved in Snap's developer flow.

### PyreChat contract

Camera Kit is an alternate camera provider, not a replacement for PyreChat's product shell.
PyreChat still owns navigation, recipients, capture review, sending, storage, messaging, safety,
and fallback. A Camera Kit capture returns a local file to the same Pyre send flow used by native
capture.


### Post-capture ownership

Camera Kit may replace or augment the live camera/lens provider, but it does not replace PyreChat's
post-capture product flow. After any provider returns a local photo/video, PyreChat owns the
full-screen review surface, caption UI, recipient picker, direct-send semantics, upload and send.
This keeps the send experience consistent whether the source is native Flutter capture or Camera Kit.
