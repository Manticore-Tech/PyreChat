import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:pyrechat_flutter/capture/ar_overlay_painter.dart';
import 'package:pyrechat_flutter/capture/custom_lens.dart';
import 'package:pyrechat_flutter/capture/face_lens_tracker.dart';
import 'package:pyrechat_flutter/capture/pyre_grades.dart';
import 'package:pyrechat_flutter/capture/pyre_landmarks.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';
import 'package:pyrechat_flutter/models/capture_send_target.dart';
import 'package:pyrechat_flutter/screens/capture/capture_hud.dart';
import 'package:pyrechat_flutter/screens/lens/lens_studio_screen.dart';
import 'package:pyrechat_flutter/services/pyre_analytics.dart';
import 'package:pyrechat_flutter/services/pyre_camera_kit.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/send_snap_sheet.dart';

/// Camera tab — Camera Kit is primary on configured Android builds; the
/// legacy Pyre camera remains a fallback for unsupported/unconfigured targets.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.active = true,
    this.sendTarget,
    this.onSendTargetConsumed,
    this.onGoChats,
    this.onGoProfile,
  });

  final bool active;
  final CaptureSendTarget? sendTarget;
  final VoidCallback? onSendTargetConsumed;
  final VoidCallback? onGoChats;
  final VoidCallback? onGoProfile;

  @override
  State<CaptureScreen> createState() => CaptureScreenState();
}

class CaptureScreenState extends State<CaptureScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  PyreGradeId _grade = PyreGradeId.none;
  PyreLensId _lens = PyreLensId.none;
  CustomLensDef? _customLens;
  List<CustomLensDef> _customLenses = [];
  bool _busy = false;
  String? _error;
  Uint8List? _lastShot;

  final _tracker = FaceLensTracker();
  final _overlayFrame = ValueNotifier<MeshFrame?>(null);
  final _stickerImages = <String, ui.Image>{};
  final _repaintTick = ValueNotifier<int>(0);
  late final Ticker _fireTicker;
  double _fireTimeMs = 0;
  bool _trackStreamOn = false;
  bool _cameraSyncing = false;
  bool _cameraSyncAgain = false;
  bool _internalCameraPause = false;
  bool _permissionSettingsRequired = false;
  bool _cameraKitConfigured = false;
  bool _cameraKitAvailabilityResolved = false;
  bool _cameraKitAutoOpenedForActivation = false;
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  bool get _arActive => _lens != PyreLensId.none || _customLens != null;
  bool get _preferCameraKit =>
      !kIsWeb && Platform.isAndroid && _cameraKitConfigured;

  bool get _shouldRunCamera =>
      widget.active &&
      _lifecycleState == AppLifecycleState.resumed &&
      !_internalCameraPause &&
      _cameraKitAvailabilityResolved &&
      !_preferCameraKit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fireTicker = createTicker((elapsed) {
      if (!_arActive) return;
      _fireTimeMs = elapsed.inMilliseconds.toDouble();
      _repaintTick.value++;
    });
    _loadCustomLenses();
    final desktopFallback = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (desktopFallback) {
      _cameraKitAvailabilityResolved = true;
      _syncCameraOwnership();
    } else {
      _refreshCameraKitAvailability();
    }
  }

  @override
  void didUpdateWidget(CaptureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (!widget.active) {
        _cameraKitAutoOpenedForActivation = false;
      }
      _handleCameraTabActivation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _handleCameraTabActivation();
  }

  Future<void> reloadCustomLenses() => _loadCustomLenses();

  Future<void> _refreshCameraKitAvailability() async {
    final configured = await PyreCameraKit.instance.isConfigured;
    if (!mounted) return;
    setState(() {
      _cameraKitConfigured = configured;
      _cameraKitAvailabilityResolved = true;
    });
    await _handleCameraTabActivation();
  }

  Future<void> _handleCameraTabActivation() async {
    if (!mounted || !_cameraKitAvailabilityResolved) return;
    if (!widget.active || _lifecycleState != AppLifecycleState.resumed) {
      await _syncCameraOwnership();
      return;
    }

    if (_preferCameraKit) {
      await _releaseCamera();
      if (_cameraKitAutoOpenedForActivation || _busy) return;
      _cameraKitAutoOpenedForActivation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && !_busy) {
          _openCameraKit();
        }
      });
      return;
    }

    await _syncCameraOwnership();
  }

  Future<void> _loadCustomLenses() async {
    final lenses = await CustomLensStore.loadAll();
    if (!mounted) return;
    setState(() => _customLenses = lenses);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTrackingStream();
    _fireTicker.dispose();
    _overlayFrame.dispose();
    _repaintTick.dispose();
    for (final img in _stickerImages.values) {
      img.dispose();
    }
    _tracker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _syncCameraOwnership() async {
    if (_cameraSyncing) {
      _cameraSyncAgain = true;
      return;
    }

    _cameraSyncing = true;
    try {
      do {
        _cameraSyncAgain = false;
        if (_shouldRunCamera) {
          await _ensureCamera();
        } else {
          await _releaseCamera();
        }
      } while (_cameraSyncAgain && mounted);
    } finally {
      _cameraSyncing = false;
    }
  }

  Future<void> _ensureCamera() async {
    final current = _controller;
    if (current != null && current.value.isInitialized) return;
    if (!_shouldRunCamera) return;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!mounted) return;
      setState(() {
        _permissionSettingsRequired = false;
        _error =
            'Pyre Camera runs on the Android/iOS alpha build. Desktop stays available for the rest of the app preview.';
      });
      return;
    }

    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!mounted || !_shouldRunCamera) return;

      _permissionSettingsRequired = status.isPermanentlyDenied;
      if (!status.isGranted) {
        setState(() {
          _error = status.isPermanentlyDenied
              ? 'Camera access is off. Enable it in system settings to use Pyre Camera.'
              : 'Camera permission is required to capture.';
        });
        return;
      }

      _permissionSettingsRequired = false;
    }
    try {
      _cameras = await availableCameras();
      if (!mounted || !_shouldRunCamera) return;
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }

      final front =
          _cameras.where((c) => c.lensDirection == CameraLensDirection.front);
      await _openCamera(front.isNotEmpty ? front.first : _cameras.first);
    } on CameraException catch (e) {
      if (!mounted || !_shouldRunCamera) return;
      setState(() => _error = e.description ?? 'Could not open the camera.');
    } on MissingPluginException {
      if (!mounted || !_shouldRunCamera) return;
      setState(() {
        _error =
            'Camera support is unavailable on this platform. Use the Android/iOS alpha build for capture.';
      });
    } on PlatformException catch (e) {
      if (!mounted || !_shouldRunCamera) return;
      setState(() => _error = e.message ?? 'Could not open the camera.');
    }
  }

  Future<void> _releaseCamera() async {
    _fireTicker.stop();
    await _stopTrackingStream();

    final controller = _controller;
    _controller = null;
    try {
      await controller?.dispose();
    } catch (_) {
      // The platform camera may already have been reclaimed by the OS.
    }

    if (mounted) setState(() {});
  }

  Future<void> _retryCamera() async {
    if (!mounted) return;
    setState(() => _error = null);
    await _syncCameraOwnership();
  }

  Future<void> _openCamera(CameraDescription camera) async {
    if (!_shouldRunCamera) return;

    await _stopTrackingStream();
    final previous = _controller;
    _controller = null;
    try {
      await previous?.dispose();
    } catch (_) {
      // Reopening after a platform camera reset should remain recoverable.
    }
    if (!_shouldRunCamera) return;

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: kIsWeb
          ? ImageFormatGroup.unknown
          : (Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21),
    );
    _controller = controller;
    if (mounted) setState(() {});

    try {
      await controller.initialize();
    } on CameraException {
      if (identical(_controller, controller)) _controller = null;
      await controller.dispose();
      rethrow;
    }

    if (!mounted || !_shouldRunCamera) {
      if (identical(_controller, controller)) _controller = null;
      await controller.dispose();
      return;
    }

    setState(() => _error = null);
    await _syncTrackingStream();
  }

  Future<void> _stopTrackingStream() async {
    final controller = _controller;
    try {
      if (controller != null && controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Lifecycle teardown can race with the platform reclaiming the camera.
    }
    _trackStreamOn = false;
    _tracker.reset();
    _overlayFrame.value = null;
  }

  Future<void> _syncTrackingStream() async {
    if (kIsWeb) {
      _trackStreamOn = false;
      _overlayFrame.value = null;
      _fireTicker.stop();
      return;
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (!_arActive) {
      await _stopTrackingStream();
      _fireTicker.stop();
      return;
    }

    if (_trackStreamOn) return;

    await controller.startImageStream((image) {
      _tracker.enqueueFrame(
        image: image,
        controller: controller,
        camera: controller.description,
        onResult: (frame) {
          if (!_arActive) return;
          _overlayFrame.value = frame;
          _repaintTick.value++;
        },
      );
    });
    _trackStreamOn = true;
    if (_lens == PyreLensId.fire && !_fireTicker.isActive) {
      _fireTicker.start();
    } else if (_lens != PyreLensId.fire && _customLens == null) {
      _fireTicker.stop();
    }
    await _preloadStickerImages();
  }

  Future<void> _preloadStickerImages() async {
    final assets = <String>{};
    if (_customLens != null) {
      for (final el in _customLens!.elements) {
        assets.add(el.asset);
      }
    }
    for (final lens in _customLenses) {
      for (final el in lens.elements) {
        assets.add(el.asset);
      }
    }

    for (final asset in assets) {
      if (_stickerImages.containsKey(asset)) continue;
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _stickerImages[asset] = frame.image;
    }
  }

  Future<void> _selectBuiltinLens(PyreLensId lens) async {
    setState(() {
      _lens = lens;
      if (lens != PyreLensId.none) _customLens = null;
    });
    if (lens == PyreLensId.fire) {
      if (!_fireTicker.isActive) _fireTicker.start();
    } else if (_customLens == null) {
      _fireTicker.stop();
    }
    await _syncTrackingStream();
  }

  Future<void> _selectCustomLens(CustomLensDef? lens) async {
    setState(() {
      _customLens = lens;
      if (lens != null) _lens = PyreLensId.none;
    });
    await _preloadStickerImages();
    await _syncTrackingStream();
  }

  Future<void> _openStudio() async {
    _internalCameraPause = true;
    await _syncCameraOwnership();

    CustomLensDef? created;
    try {
      if (!mounted) return;
      created = await Navigator.of(context).push<CustomLensDef>(
        MaterialPageRoute(builder: (_) => const LensStudioScreen()),
      );
    } finally {
      _internalCameraPause = false;
      if (mounted) await _syncCameraOwnership();
    }

    if (created != null && mounted) {
      await CustomLensStore.upsert(created);
      await _loadCustomLenses();
      await _selectCustomLens(created);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _controller == null || _busy) return;
    final current = _controller!.description;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection != current.lensDirection,
      orElse: () => _cameras.first,
    );

    setState(() => _busy = true);
    try {
      await _openCamera(next);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.description ?? 'Could not switch cameras.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();

    final wasTracking = _trackStreamOn;
    if (wasTracking) await _stopTrackingStream();

    try {
      PyreAnalytics.instance.track('camera_native_open', surface: 'camera');
      final file = await controller.takePicture();
      PyreAnalytics.instance.track('camera_capture_photo', surface: 'camera_native');
      final lensDir = controller.description.lensDirection;
      var decoded = img.decodeImage(await file.readAsBytes());

      if (decoded != null && _lens != PyreLensId.none) {
        final mesh = await _tracker.detectOnFile(file.path);
        if (mesh != null) {
          decoded = await compositeLensOnImage(
            source: decoded,
            imageSpacePoints: mesh,
            lens: _lens,
            lensDirection: lensDir,
          );
        }
      }

      if (decoded != null && _customLens != null) {
        final mesh = await _tracker.detectOnFile(file.path);
        if (mesh != null) {
          decoded = await compositeCustomLensOnImage(
            source: decoded,
            imageSpacePoints: mesh,
            lens: _customLens!,
            stickerImages: _stickerImages,
            lensDirection: lensDir,
          );
        }
      }

      if (decoded != null && _grade != PyreGradeId.none) {
        decoded = PyreGrades.applyToImage(decoded, _grade);
      }

      final out = decoded == null
          ? await file.readAsBytes()
          : Uint8List.fromList(img.encodeJpg(decoded, quality: 92));

      if (!mounted) return;
      setState(() => _lastShot = out);

      final label = _customLens?.name ?? PyreLenses.all.firstWhere((l) => l.id == _lens).label;
      final target = widget.sendTarget;
      final sent = await showSendSnapSheet(
        context: context,
        imageBytes: out,
        conversationId: target?.conversationId,
        recipientIds: target?.canPreselect == true ? target!.recipientIds : null,
        recipientLabel: target?.canPreselect == true ? target!.label : null,
      );
      if (!mounted) return;
      if (sent) {
        PyreAnalytics.instance.track('camera_send', surface: 'camera_native');
        widget.onSendTargetConsumed?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pyre sent'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: PyreColors.panel,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Captured · ${PyreGrades.byId(_grade).label} · $label'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: PyreColors.panel,
          ),
        );
      }
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.description ?? 'Capture failed')),
      );
    } finally {
      if (wasTracking && mounted && _arActive) {
        _trackStreamOn = false;
        await _syncTrackingStream();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCameraKit() async {
    if (_busy) return;

    if (!_cameraKitConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera Kit is wired in, but this build still needs an approved Snap API token and Lens Group.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: PyreColors.panel,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    _internalCameraPause = true;
    await _syncCameraOwnership();

    try {
      PyreAnalytics.instance.track('camera_kit_open', surface: 'camera');
      final result = await PyreCameraKit.instance.capture();
      if (!mounted || result == null) return;
      PyreAnalytics.instance.track('camera_kit_return', surface: 'camera');
      final mime = result.uploadMime;
      if (mime == null) {
        throw PlatformException(
          code: 'camera_kit_unsupported_media',
          message: 'Camera Kit returned an unsupported media type',
        );
      }

      if (result.isVideo) {
        PyreAnalytics.instance.track(
          'camera_capture_video',
          surface: 'camera_kit',
        );
        final bytes = await File(result.path).readAsBytes();
        if (!mounted) return;

        final target = widget.sendTarget;
        final sent = await showSendSnapVideoSheet(
          context: context,
          videoBytes: bytes,
          videoPath: result.path,
          mime: mime,
          conversationId: target?.conversationId,
          recipientIds:
              target?.canPreselect == true ? target!.recipientIds : null,
          recipientLabel: target?.canPreselect == true ? target!.label : null,
        );
        if (!mounted) return;
        if (sent) {
          PyreAnalytics.instance.track(
            'camera_send',
            surface: 'camera_kit_video',
          );
          widget.onSendTargetConsumed?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pyre sent'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: PyreColors.panel,
            ),
          );
        }
        return;
      }

      PyreAnalytics.instance.track(
        'camera_capture_photo',
        surface: 'camera_kit',
      );
      final bytes = await File(result.path).readAsBytes();
      if (!mounted) return;

      setState(() => _lastShot = bytes);

      final target = widget.sendTarget;
      final sent = await showSendSnapSheet(
        context: context,
        imageBytes: bytes,
        imagePath: result.path,
        mime: mime,
        conversationId: target?.conversationId,
        recipientIds: target?.canPreselect == true ? target!.recipientIds : null,
        recipientLabel: target?.canPreselect == true ? target!.label : null,
      );
      if (!mounted) return;

      if (sent) {
        PyreAnalytics.instance.track(
          'camera_send',
          surface: 'camera_kit_photo',
        );
        widget.onSendTargetConsumed?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pyre sent'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: PyreColors.panel,
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Camera Kit could not open'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: PyreColors.panel,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera Kit could not open'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: PyreColors.panel,
        ),
      );
    } finally {
      _internalCameraPause = false;
      if (mounted) {
        setState(() => _busy = false);
        await _syncCameraOwnership();
      }
    }
  }

  Future<void> _sendLastShot() async {
    final shot = _lastShot;
    if (shot == null) return;
    final target = widget.sendTarget;
    final sent = await showSendSnapSheet(
      context: context,
      imageBytes: shot,
      conversationId: target?.conversationId,
      recipientIds: target?.canPreselect == true ? target!.recipientIds : null,
      recipientLabel: target?.canPreselect == true ? target!.label : null,
    );
    if (!mounted || !sent) return;
    widget.onSendTargetConsumed?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pyre sent'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PyreColors.panel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_preferCameraKit) {
      return _MessageScaffold(
        icon: Icons.photo_camera_outlined,
        title: 'Camera',
        message: _busy
            ? 'Opening camera…'
            : 'Snap Camera Kit is the PyreChat camera on this device.',
        action: FilledButton.icon(
          onPressed: _busy ? null : _openCameraKit,
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(_busy ? 'Opening…' : 'Open camera'),
        ),
      );
    }

    if (_error != null) {
      final desktop = !kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
      return _MessageScaffold(
        icon: Icons.photo_camera_outlined,
        title: 'Camera',
        message: _error!,
        action: desktop
            ? null
            : TextButton(
                onPressed: _permissionSettingsRequired
                    ? () async {
                        await openAppSettings();
                      }
                    : _retryCamera,
                child: Text(
                  _permissionSettingsRequired ? 'Open settings' : 'Try again',
                ),
              ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: PyreColors.ink,
        child: Center(
          child: Semantics(
            label: 'Loading camera',
            liveRegion: true,
            child: ExcludeSemantics(
              child: CircularProgressIndicator(color: PyreColors.ember),
            ),
          ),
        ),
      );
    }

    final grade = PyreGrades.byId(_grade);
    final previewSize = controller.value.previewSize;
    final childW = previewSize?.height ?? 1.0;
    final childH = previewSize?.width ?? 1.0;

    return ColoredBox(
      color: PyreColors.ink,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: childW,
              height: childH,
              child: _FilteredPreview(
                controller: controller,
                matrix: grade.matrix,
                overlay: _arActive
                    ? ListenableBuilder(
                        listenable: Listenable.merge([_overlayFrame, _repaintTick]),
                        builder: (context, _) {
                          return RepaintBoundary(
                            child: CustomPaint(
                              painter: ArOverlayPainter(
                                frame: _overlayFrame.value,
                                lens: _lens,
                                customLens: _customLens,
                                stickerImages: _stickerImages,
                                timeMs: _fireTimeMs,
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            ),
          ),
          CaptureHud(
            lens: _lens,
            customLens: _customLens,
            customLenses: _customLenses,
            grade: _grade,
            busy: _busy,
            lastShot: _lastShot,
            onLensSelected: _selectBuiltinLens,
            onCustomLensSelected: _selectCustomLens,
            onOpenStudio: _openStudio,
            onGradeSelected: (g) => setState(() => _grade = g),
            onCapture: _capture,
            onFlip: _flipCamera,
            onOpenCameraKit: _openCameraKit,
            cameraKitConfigured: _cameraKitConfigured,
            onTapLastShot: _sendLastShot,
            onGoChats: widget.onGoChats,
            onGoProfile: widget.onGoProfile,
          ),
        ],
      ),
    );
  }
}

class _FilteredPreview extends StatelessWidget {
  const _FilteredPreview({
    required this.controller,
    this.matrix,
    this.overlay,
  });

  final CameraController controller;
  final List<double>? matrix;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    Widget preview = CameraPreview(controller, child: overlay);
    if (matrix != null) {
      preview = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix!),
        child: preview,
      );
    }
    return preview;
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PyreColors.night,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
              decoration: BoxDecoration(
                color: PyreColors.nightCardStrong,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 78,
                      height: 78,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PyreColors.ember.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        icon,
                        color: PyreColors.emberGlow,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label: '$title. $message',
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: PyreColors.nightText,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: PyreColors.nightMuted,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
