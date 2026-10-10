import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/screens/chats/pyre_rcs_screen.dart';
import 'package:pyrechat_flutter/services/appearance_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_notifications.dart';
import 'package:pyrechat_flutter/theme/pyre_scroll_behavior.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  unawaited(AppearancePrefs.instance.load());
  PyreNotifications.instance.init();
  runApp(const PyreChatApp());
}

class PyreChatApp extends StatelessWidget {
  const PyreChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppearancePrefs.instance;
    return AnimatedBuilder(
      animation: appearance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Pyre Social',
          debugShowCheckedModeBanner: false,
          theme: pyreTheme(accentColor: appearance.accentColor),
          scrollBehavior: const PyreScrollBehavior(),
          // Owner-directed fresh start: the first-party RCS identity is now
          // the application's sole login and messaging entry point.
          home: const PyreRcsInboxScreen(),
        );
      },
    );
  }
}
