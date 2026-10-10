import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/pages/onboarding/onboarding_page.dart';
// Load the camera, realtime, and encryption-heavy signed-in shell only when
// an account is active. Unauthenticated web visitors can reach login sooner.
import 'package:pyrechat_flutter/screens/app_shell_screen.dart' deferred as shell;
import 'package:pyrechat_flutter/services/chat_cache.dart';
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
  Future<void>? _shellLibrary;

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
    final cachedUser = _user ?? await _session.user;
    if (cachedUser != null) {
      await ChatCache.instance.clearUser(cachedUser.id);
    }
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

    final cached = await _session.user;
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _user = cached;
        _booting = false;
      });
      unawaited(_refreshSession(token, cachedUser: cached));
      return;
    }

    await _refreshSession(token, requiredForBoot: true);
  }

  Future<void> _refreshSession(
    String token, {
    PyreUser? cachedUser,
    bool requiredForBoot = false,
  }) async {
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
        final user = cachedUser ?? await _session.user;
        if (user != null) {
          await ChatCache.instance.clearUser(user.id);
        }
        await _session.clear();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() {
          _user = null;
          _booting = false;
          _sessionNotice = 'Your session expired. Sign in again.';
        });
        return;
      }

      // Network/server trouble is not an authentication decision. If a cached
      // identity exists, the signed-in shell remains authoritative locally.
      if (!mounted || !requiredForBoot) return;
      setState(() {
        _user = cachedUser;
        _booting = false;
      });
    } catch (_) {
      // Same rule for transport/DNS/timeouts: preserve local signed-in state.
      if (!mounted || !requiredForBoot) return;
      setState(() {
        _user = cachedUser;
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
      return FutureBuilder<void>(
        future: _shellLibrary ??= shell.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              backgroundColor: PyreColors.ember,
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not finish loading PyreChat. Please reload to try again.',
                    style: TextStyle(color: PyreColors.paper),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              backgroundColor: PyreColors.ember,
              body: Center(
                child: CircularProgressIndicator(color: PyreColors.paper),
              ),
            );
          }
          return shell.AppShellScreen(user: _user!);
        },
      );
    }

    return OnboardingPage(
      onAuthenticated: _onAuthenticated,
      notice: _sessionNotice,
    );
  }
}
