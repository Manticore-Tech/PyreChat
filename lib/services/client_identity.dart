import 'package:flutter/foundation.dart';

String pyreClientLabel() {
  if (kIsWeb) return 'PyreChat Web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'PyreChat Android',
    TargetPlatform.iOS => 'PyreChat iPhone',
    TargetPlatform.macOS => 'PyreChat macOS',
    TargetPlatform.windows => 'PyreChat Windows',
    TargetPlatform.linux => 'PyreChat Linux',
    TargetPlatform.fuchsia => 'PyreChat',
  };
}
