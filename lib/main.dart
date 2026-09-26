import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/app/app_bootstrap.dart';
import 'package:pyrechat_flutter/services/pyre_notifications.dart';
import 'package:pyrechat_flutter/theme/pyre_scroll_behavior.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PyreNotifications.instance.init();
  runApp(const PyreChatApp());
}

class PyreChatApp extends StatelessWidget {
  const PyreChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PyreChat',
      debugShowCheckedModeBanner: false,
      theme: pyreTheme(),
      scrollBehavior: const PyreScrollBehavior(),
      home: const AppBootstrap(),
    );
  }
}
