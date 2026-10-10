import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/services/pyre_analytics.dart';

class PyreMediaSaver {
  PyreMediaSaver._();

  static const MethodChannel _channel = MethodChannel(
    'dev.pyrearms.pyrechat/media_saver',
  );

  static Future<String?> save({
    required String kind,
    required String mime,
    String? path,
    Uint8List? bytes,
  }) async {
    final result = await _channel.invokeMethod<String>('saveMedia', <String, Object?>{
      'kind': kind,
      'mime': mime,
      'path': path,
      'bytes': path == null || path.isEmpty ? bytes : null,
    });
    if (result != null && result.isNotEmpty) {
      PyreAnalytics.instance.track(
        'camera_save_device',
        surface: kind == 'video' ? 'save_video' : 'save_photo',
      );
    }
    return result;
  }
}
