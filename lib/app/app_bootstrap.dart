import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/pages/onboarding/onboarding_page.dart';
import 'package:pyrechat_flutter/screens/app_shell_screen.dart';
import 'package:pyrechat_flutter/services/chat_draft_store.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/session_events.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

/// Restores a saved session on cold start, then routes to auth or the main shell.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  final _session = SessionStore();
  final _api = PyreApi();

  PyreUser? _user;
  bool _booting = true;
  bool _clearingInvalidSession = false;
  String? _sessionNotice;

  @override
  void initState() {
    super.initState();
    SessionEvents.instance.addInvalidatedListener(_onSessionInvalidated);
    _restoreSession();
  }

  @override
  void dispose() {
    SessionEvents.instance.removeInvalidatedListener(_onSessionInvalidated);
    super.dispose();
  }

  void _onSessionInvalidated(String message) {
    _clearInvalidSession(message);
  }

  Future<void> _clearInvalidSession(String message) async {
    if (_clearingInvalidSession) return;
    _clearingInvalidSession = true;
    await _session.clear();
    ChatDraftStore.instance.clearAll();
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _user = null;
      _booting = false;
      _sessionNotice = message;
      _clearingInvalidSession = false;
    });
  }

  void _onAuthenticated(PyreUser user) {
    if (!mounted) return;
    setState(() {
      _user = user;
      _sessionNotice = null;
    });
  }

  Future<void> _restoreSession() async {
    final token = await _session.token;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _booting = false);
      return;
    }

    try {
      final user = await _api.me(token: token);
      await _session.save(token: token, user: user);
      if (!mounted) return;
      setState(() {
        _user = user;
        _booting = false;
      });
    } on PyreApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _session.clear();
      } else {
        final cached = await _session.user;
        if (!mounted) return;
        setState(() {
          _user = cached;
          _booting = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _booting = false);
    } catch (_) {
      final cached = await _session.user;
      if (!mounted) return;
      setState(() {
        _user = cached;
        _booting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        backgroundColor: PyreColors.ember,
        body: Center(
          child: CircularProgressIndicator(color: PyreColors.paper),
        ),
      );
    }

    if (_user != null) {
      return AppShellScreen(user: _user!);
    }

    return OnboardingPage(
      onAuthenticated: _onAuthenticated,
      notice: _sessionNotice,
    );
  }
}
