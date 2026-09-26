import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/capture_send_target.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/capture/capture_screen.dart';
import 'package:pyrechat_flutter/screens/chats/chats_screen.dart';
import 'package:pyrechat_flutter/screens/profile/profile_screen.dart';
import 'package:pyrechat_flutter/screens/pyre/pyre_page_screen.dart';
import 'package:pyrechat_flutter/services/pyre_hub.dart';
import 'package:pyrechat_flutter/services/pyre_notifications.dart';
import 'package:pyrechat_flutter/theme/pyre_motion.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/leave_app_dialog.dart';
import 'package:pyrechat_flutter/widgets/pyre_bottom_nav.dart';

enum _AppTab { chats, pyre, camera, profile }

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key, required this.user});

  final PyreUser user;

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen>
    with WidgetsBindingObserver {
  static const _tabs = _AppTab.values;
  final _captureKey = GlobalKey<CaptureScreenState>();
  final _chatsKey = GlobalKey<ChatsScreenState>();
  final _hub = PyreHub();

  late final PageController _pages;
  _AppTab _tab = _AppTab.chats;
  CaptureSendTarget? _captureTarget;
  bool _appResumed = true;

  void _onHubEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == 'pong') return;

    // The Pyre intentionally never maps room activity to system notifications.
    // Direct chat/snap/account events retain their normal notification behavior.
    if (!_appResumed || _tab != _AppTab.chats) {
      PyreNotifications.instance.handleHubEvent(event);
    }

    if (type == 'chat' ||
        type == 'snap' ||
        type == 'notification' ||
        event['kind'] == 'snap') {
      _chatsKey.currentState?.reload(silent: true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = PageController(initialPage: _tab.index);
    _hub.addListener(_onHubEvent);
    _hub.connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hub.removeListener(_onHubEvent);
    _hub.disconnect();
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (!_appResumed) return;

    _hub.reconnect();
    _chatsKey.currentState?.reload(silent: true);
  }

  void _openCamera(CaptureSendTarget? target) {
    if (mounted) setState(() => _captureTarget = target);
    _goToTab(_AppTab.camera);
  }

  void _clearCaptureTarget() {
    if (_captureTarget == null || !mounted) return;
    setState(() => _captureTarget = null);
  }

  void _goToTab(_AppTab tab) {
    if (tab != _AppTab.camera && _captureTarget != null) {
      _clearCaptureTarget();
    }
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _pages.animateToPage(
      tab.index,
      duration: PyreMotion.standard,
      curve: PyreMotion.enter,
    );
  }

  void _onPageChanged(int index) {
    final next = _tabs[index];
    if (next != _AppTab.camera && _captureTarget != null) {
      _clearCaptureTarget();
    }
    if (_tab == next) return;
    setState(() => _tab = next);

    if (next == _AppTab.camera) {
      _captureKey.currentState?.reloadCustomLenses();
    }
    if (next == _AppTab.chats) {
      _chatsKey.currentState?.reload(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        maybeLeaveApp(context);
      },
      child: Scaffold(
        backgroundColor: PyreColors.night,
        extendBody: true,
        body: PageView(
          controller: _pages,
          onPageChanged: _onPageChanged,
          physics: const PageScrollPhysics(),
          children: [
            ChatsScreen(
              key: _chatsKey,
              hub: _hub,
              user: widget.user,
              onGoCamera: _openCamera,
            ),
            PyrePageScreen(user: widget.user),
            CaptureScreen(
              key: _captureKey,
              active: _tab == _AppTab.camera,
              sendTarget: _captureTarget,
              onSendTargetConsumed: _clearCaptureTarget,
              onGoChats: () => _goToTab(_AppTab.chats),
              onGoProfile: () => _goToTab(_AppTab.profile),
            ),
            ProfileScreen(user: widget.user),
          ],
        ),
        bottomNavigationBar: _tab == _AppTab.camera
            ? null
            : PyreBottomNav(
                selectedIndex: _tab.index,
                onSelected: (i) => _goToTab(_tabs[i]),
              ),
      ),
    );
  }
}
