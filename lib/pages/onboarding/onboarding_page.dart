import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/auth/auth_form_state.dart';
import 'package:pyrechat_flutter/auth/birthday_input.dart';
import 'package:pyrechat_flutter/auth/birthday_validation.dart';
import 'package:pyrechat_flutter/auth/signup_validation.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/fade_page_view.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_choice_slide.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_intro_slide.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_login_slide.dart';
import 'package:pyrechat_flutter/pages/onboarding/widgets/onboarding_signup_slide.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/leave_app_dialog.dart';
import 'package:pyrechat_flutter/widgets/recovery_key_dialog.dart';

/// Single onboarding host (FlutterFlow-style): one page, cross-fading steps.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onAuthenticated,
    this.notice,
  });

  final ValueChanged<PyreUser> onAuthenticated;
  final String? notice;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _intro = 0;
  static const _choice = 1;
  static const _login = 2;
  static const _signup = 3;

  final _forms = AuthFormState();
  final _api = PyreApi();
  final _session = SessionStore();

  late int _page;
  final _signupKey = GlobalKey<OnboardingSignupSlideState>();
  final _choiceKey = GlobalKey<OnboardingChoiceSlideState>();

  @override
  void initState() {
    super.initState();
    _page = widget.notice == null ? _intro : _choice;
  }

  void _goTo(int index) {
    if (index == _page) return;
    setState(() => _page = index);
  }

  void _enterApp(PyreUser user) {
    widget.onAuthenticated(user);
  }

  Future<void> _submitLogin() async {
    if (_forms.loginBusy) return;
    final user = _forms.username.trim();
    if (user.isEmpty || _forms.password.isEmpty) {
      setState(() => _forms.loginError = 'Enter username and password');
      return;
    }
    setState(() {
      _forms.loginBusy = true;
      _forms.loginError = null;
    });
    try {
      final result = await _api.login(
        username: user,
        password: _forms.password,
      );
      await _session.save(token: result.token, user: result.user);
      if (!mounted) return;
      _enterApp(result.user);
    } on PyreApiException catch (e) {
      if (mounted) setState(() => _forms.loginError = e.message);
    } catch (_) {
      if (mounted) setState(() => _forms.loginError = 'Could not log in');
    } finally {
      if (mounted) setState(() => _forms.loginBusy = false);
    }
  }

  Future<void> _submitSignup() async {
    if (_forms.signupBusy) return;
    final normalizedBirthday = normalizeBirthdayInput(_forms.birthday);
    final validationError = validateDisplayName(_forms.displayName) ??
        validateUsername(_forms.signupUsername) ??
        validatePyreBirthday(_forms.birthday) ??
        validateSignupPassword(_forms.signupPassword);
    if (validationError != null) {
      setState(() => _forms.signupError = validationError);
      return;
    }

    setState(() {
      _forms.signupBusy = true;
      _forms.signupError = null;
    });
    try {
      final result = await _api.signup(
        username: _forms.signupUsername.trim(),
        password: _forms.signupPassword,
        displayName: _forms.displayName.trim(),
        birthday: normalizedBirthday!,
      );
      await _session.save(token: result.token, user: result.user);
      if (!mounted) return;
      final recoveryKey = result.recoveryKey?.trim();
      if (recoveryKey != null && recoveryKey.isNotEmpty) {
        await showRecoveryKeyDialog(context: context, recoveryKey: recoveryKey);
      }

      if (!mounted) return;
      _enterApp(result.user);
    } on PyreApiException catch (e) {
      if (mounted) setState(() => _forms.signupError = e.message);
    } catch (_) {
      if (mounted) setState(() => _forms.signupError = 'Could not sign up');
    } finally {
      if (mounted) setState(() => _forms.signupBusy = false);
    }
  }

  void _openSignup() {
    _forms.resetSignup();
    _signupKey.currentState?.resetToFirstStep();
    _goTo(_signup);
  }

  void _openLogin() {
    _forms.loginError = null;
    _goTo(_login);
  }

  Future<void> _handleBack() async {
    if (_page == _intro) {
      if (!mounted) return;
      await maybeLeaveApp(context);
      return;
    }
    if (_page == _signup) {
      final handled = await _signupKey.currentState?.handleBack() ?? false;
      if (handled) return;
      _goTo(_choice);
      return;
    }
    if (_page == _login) {
      _goTo(_choice);
      return;
    }
    if (_page == _choice) {
      final collapsed = await _choiceKey.currentState?.collapseToIdle() ?? false;
      if (collapsed) return;
      if (!mounted) return;
      await maybeLeaveApp(context);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: PyreColors.ember,
        body: Stack(
          children: [
            FadePageView(
              index: _page,
              duration: onboardingDissolveDuration,
              curve: onboardingDissolveCurve,
              children: [
                OnboardingIntroSlide(onFinished: () => _goTo(_choice)),
                OnboardingChoiceSlide(
                  key: _choiceKey,
                  onLogin: _openLogin,
                  onSignup: _openSignup,
                ),
                OnboardingLoginSlide(
                  username: _forms.username,
                  password: _forms.password,
                  busy: _forms.loginBusy,
                  error: _forms.loginError,
                  onUsernameChanged: (v) => setState(() {
                    _forms.username = v;
                    _forms.loginError = null;
                  }),
                  onPasswordChanged: (v) => setState(() {
                    _forms.password = v;
                    _forms.loginError = null;
                  }),
                  onSubmit: _submitLogin,
                ),
                OnboardingSignupSlide(
                  key: _signupKey,
                  forms: _forms,
                  onChanged: () => setState(() {}),
                  onSubmit: _submitSignup,
                ),
              ],
            ),
            if (widget.notice != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: PyreColors.paper,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.notice!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PyreColors.onPaper,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
