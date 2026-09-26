import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pyrechat_flutter/capture/ar_overlay_painter.dart';
import 'package:pyrechat_flutter/capture/custom_lens.dart';
import 'package:pyrechat_flutter/capture/face_lens_tracker.dart';
import 'package:pyrechat_flutter/capture/pyre_landmarks.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';

/// In-app lens maker — native preview + live sticker overlay.
class LensStudioScreen extends StatefulWidget {
  const LensStudioScreen({
    super.key,
    this.bootCamera = true,
  });

  final bool bootCamera;

  @override
  State<LensStudioScreen> createState() => _LensStudioScreenState();
}

class _LensStudioScreenState extends State<LensStudioScreen> with TickerProviderStateMixin {
  static const _stickers = [
    PyreIcons.flame,
    PyreIcons.flamePlus,
    'assets/icons/heart_filled.png',
    'assets/icons/star_filled.png',
    'assets/icons/flame_sparkle.png',
  ];

  CameraController? _controller;
  final _tracker = FaceLensTracker();
  final _nameCtrl = TextEditingController(text: 'My Lens');
  final _draft = <CustomLensElement>[];
  final _stickerImages = <String, ui.Image>{};
  final _overlayFrame = ValueNotifier<MeshFrame?>(null);
  final _repaintTick = ValueNotifier<int>(0);

  bool _trackStreamOn = false;
  bool _closing = false;
  int _anchorIndex = 10;
  String _pickedSticker = PyreIcons.flame;
  double _scale = 1;

  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _repaintTick.value++);
    if (widget.bootCamera) _boot();
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    _ticker.dispose();
    _overlayFrame.dispose();
    _repaintTick.dispose();
    _nameCtrl.dispose();
    for (final img in _stickerImages.values) {
      img.dispose();
    }
    _tracker.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _releaseCameraBeforePop() async {
    final controller = _controller;
    _controller = null;
    _trackStreamOn = false;
    _ticker.stop();

    if (controller == null) return;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // The platform may already be tearing the camera down.
    }

    try {
      await controller.dispose();
    } catch (_) {
      // Treat an already-released camera as successfully closed.
    }
  }

  Future<void> _close([CustomLensDef? result]) async {
    if (_closing) return;
    _closing = true;
    await _releaseCameraBeforePop();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _boot() async {
    if (!await Permission.camera.request().isGranted) return;
    final cams = await availableCameras();
    if (cams.isEmpty) return;
    final front = cams.where((c) => c.lensDirection == CameraLensDirection.front);
    final cam = front.isNotEmpty ? front.first : cams.first;

    final controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
    );
    _controller = controller;
    await controller.initialize();
    await _preloadStickers();
    if (!mounted) return;
    setState(() {});
    await _startStream();
  }

  Future<void> _preloadStickers() async {
    for (final asset in _stickers) {
      if (_stickerImages.containsKey(asset) || !mounted) continue;
      final data = await DefaultAssetBundle.of(context).load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _stickerImages[asset] = frame.image;
    }
  }

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _trackStreamOn) return;

    await controller.startImageStream((image) {
      _tracker.enqueueFrame(
        image: image,
        controller: controller,
        camera: controller.description,
        onResult: (frame) => _overlayFrame.value = frame,
      );
    });
    _trackStreamOn = true;
    _ticker.start();
  }

  void _addSticker() {
    setState(() {
      _draft.add(
        CustomLensElement(
          anchorIndex: _anchorIndex,
          asset: _pickedSticker,
          scale: _scale,
        ),
      );
    });
    _repaintTick.value++;
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one sticker and a name')),
      );
      return;
    }
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final lens = CustomLensDef(id: id, name: name, elements: List.unmodifiable(_draft));

    if (Navigator.canPop(context)) {
      await _close(lens);
      return;
    }

    await CustomLensStore.upsert(lens);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "$name" — open Camera to use it')),
    );
    setState(() => _draft.clear());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final draftLens = CustomLensDef(id: 'draft', name: 'draft', elements: _draft);
    final previewSize = controller?.value.previewSize;
    final childW = previewSize?.height ?? 1.0;
    final childH = previewSize?.width ?? 1.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: PyreColors.ink,
        appBar: AppBar(
          backgroundColor: PyreColors.ink,
          foregroundColor: PyreColors.paper,
          leading: IconButton(
            onPressed: _closing ? null : _close,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Lens Studio', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            TextButton(onPressed: _closing ? null : _save, child: const Text('Save')),
          ],
        ),
      body: LayoutBuilder(
        builder: (context, bodyConstraints) {
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          final editorMaxHeight =
              bodyConstraints.maxHeight * (keyboardOpen ? 0.72 : 0.52);

          return Column(
            children: [
              Expanded(
            child: controller == null || !controller.value.isInitialized
                ? const Center(child: CircularProgressIndicator(color: PyreColors.ember))
                : FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: childW,
                      height: childH,
                      child: CameraPreview(
                        controller,
                        child: ListenableBuilder(
                          listenable: Listenable.merge([_overlayFrame, _repaintTick]),
                          builder: (context, _) => CustomPaint(
                            painter: ArOverlayPainter(
                              frame: _overlayFrame.value,
                              lens: PyreLensId.none,
                              customLens: _draft.isEmpty ? null : draftLens,
                              stickerImages: _stickerImages,
                              timeMs: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: editorMaxHeight),
                child: Container(
                  color: PyreColors.panel,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: PyreColors.paper),
                      decoration: const InputDecoration(
                        labelText: 'Lens name',
                        labelStyle: TextStyle(color: PyreColors.mute),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _anchorIndex,
                      dropdownColor: PyreColors.panel,
                      style: const TextStyle(color: PyreColors.paper),
                      decoration: const InputDecoration(labelText: 'Anchor point'),
                      items: LensAnchors.presets.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _anchorIndex = v ?? 10),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Size', style: TextStyle(color: PyreColors.mute)),
                        Expanded(
                          child: Slider(
                            value: _scale,
                            min: 0.4,
                            max: 2.5,
                            activeColor: PyreColors.ember,
                            onChanged: (v) => setState(() => _scale = v),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _stickers.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final asset = _stickers[i];
                          final on = asset == _pickedSticker;
                          return GestureDetector(
                            onTap: () => setState(() => _pickedSticker = asset),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: on ? PyreColors.ember : PyreColors.mute.withValues(alpha: 0.3),
                                  width: on ? 2 : 1,
                                ),
                                color: PyreColors.ink,
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Image.asset(asset),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _draft.isEmpty
                                ? null
                                : () => setState(() => _draft.removeLast()),
                            child: const Text('Undo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: PyreColors.ember,
                            ),
                            onPressed: _addSticker,
                            child: const Text('Place sticker'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }
}
