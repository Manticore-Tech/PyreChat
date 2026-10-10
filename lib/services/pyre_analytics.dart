import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pyrechat_flutter/services/client_identity.dart';

class PyreAnalytics {
  PyreAnalytics._();

  static final PyreAnalytics instance = PyreAnalytics._();

  static const _origin = String.fromEnvironment(
    'PYRE_API_ORIGIN',
    defaultValue: 'https://chat.pyrearms.dev',
  );

  static const _timeout = Duration(seconds: 5);

  String get _platform {
    if (kIsWeb) return 'flutter_web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  void track(
    String event, {
    String surface = '',
    String source = '',
    String campaign = '',
  }) {
    unawaited(
      _send(
        event,
        surface: surface,
        source: source,
        campaign: campaign,
      ),
    );
  }

  Future<void> _send(
    String event, {
    required String surface,
    required String source,
    required String campaign,
  }) async {
    try {
      final origin = _origin.endsWith('/')
          ? _origin.substring(0, _origin.length - 1)
          : _origin;
      await http
          .post(
            Uri.parse('$origin/api/metrics'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Pyre-Client': pyreClientLabel(),
            },
            body: jsonEncode(<String, String>{
              'event': event,
              'platform': _platform,
              if (surface.isNotEmpty) 'surface': surface,
              if (source.isNotEmpty) 'source': source,
              if (campaign.isNotEmpty) 'campaign': campaign,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // Product analytics are intentionally best-effort and must never block UI,
      // messaging, Camera Kit, authentication, or recovery.
    }
  }
}
