import 'package:flutter/services.dart';

class PyreExternalLinks {
  PyreExternalLinks._();

  static const MethodChannel _channel = MethodChannel(
    'dev.pyrearms.pyrechat/external_links',
  );

  static Future<bool> open(String url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
