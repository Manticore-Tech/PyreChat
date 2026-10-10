import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_media_saver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.pyrearms.pyrechat/media_saver');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('save prefers source path when available', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return 'content://media/saved/1';
    });

    final uri = await PyreMediaSaver.save(
      kind: 'photo',
      mime: 'image/jpeg',
      path: '/tmp/camera-kit.jpg',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(uri, 'content://media/saved/1');
    expect(captured?.method, 'saveMedia');
    expect(captured?.arguments['path'], '/tmp/camera-kit.jpg');
    expect(captured?.arguments['bytes'], isNull);
    expect(captured?.arguments['mime'], 'image/jpeg');
    expect(captured?.arguments['kind'], 'photo');
  });

  test('save falls back to bytes when no source path exists', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return 'content://media/saved/2';
    });

    final bytes = Uint8List.fromList([9, 8, 7]);
    await PyreMediaSaver.save(
      kind: 'photo',
      mime: 'image/png',
      bytes: bytes,
    );

    expect(captured?.arguments['path'], isNull);
    expect(captured?.arguments['bytes'], bytes);
  });

  test('save preserves video kind and MIME for Android MediaStore', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return 'content://media/saved/video';
    });

    final uri = await PyreMediaSaver.save(
      kind: 'video',
      mime: 'video/mp4',
      path: '/tmp/camera-kit.mp4',
      bytes: Uint8List.fromList([1, 2]),
    );

    expect(uri, 'content://media/saved/video');
    expect(captured?.method, 'saveMedia');
    expect(captured?.arguments['kind'], 'video');
    expect(captured?.arguments['mime'], 'video/mp4');
    expect(captured?.arguments['path'], '/tmp/camera-kit.mp4');
    expect(captured?.arguments['bytes'], isNull);
  });

  test('native save failure is surfaced for review-sheet handling', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'save_failed', message: 'Disk full');
    });

    await expectLater(
      PyreMediaSaver.save(kind: 'photo', mime: 'image/jpeg', bytes: Uint8List(1)),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'save_failed')
            .having((e) => e.message, 'message', 'Disk full'),
      ),
    );
  });

  test('missing native save plugin surfaces MissingPluginException', () async {
    await expectLater(
      PyreMediaSaver.save(kind: 'photo', mime: 'image/jpeg', bytes: Uint8List(1)),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
