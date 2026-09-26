import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/auth/birthday_input.dart';
import 'package:pyrechat_flutter/auth/auth_form_state.dart';
import 'package:pyrechat_flutter/auth/birthday_validation.dart';
import 'package:pyrechat_flutter/auth/signup_step.dart';
import 'package:pyrechat_flutter/auth/signup_validation.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/signup_question.dart';

/// Nested [PageView] for signup questions — parent onboarding page stays one route.
class OnboardingSignupSlide extends StatefulWidget {
  const OnboardingSignupSlide({
    super.key,
    required this.forms,
    required this.onChanged,
    required this.onSubmit,
  });

  final AuthFormState forms;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  State<OnboardingSignupSlide> createState() => OnboardingSignupSlideState();
}

class OnboardingSignupSlideState extends State<OnboardingSignupSlide> {
  final _stepController = PageController();
  static const _steps = SignupStep.values;

  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.forms.displayName);
    _usernameController = TextEditingController(text: widget.forms.signupUsername);
    _birthdayController = TextEditingController(text: widget.forms.birthday);
    _passwordController = TextEditingController(text: widget.forms.signupPassword);
  }

  @override
  void dispose() {
    _stepController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _birthdayController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void resetToFirstStep() {
    widget.forms.signupStep = SignupStep.displayName;
    _displayNameController.clear();
    _usernameController.clear();
    _birthdayController.clear();
    _passwordController.clear();
    if (_stepController.hasClients) {
      _stepController.jumpToPage(0);
    }
  }

  Future<void> _goToStep(SignupStep step) async {
    final index = _steps.indexOf(step);
    widget.forms.signupStep = step;
    widget.onChanged();
    if (!_stepController.hasClients) return;
    await _stepController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<bool> handleBack() async {
    final prev = widget.forms.signupStep.previous;
    if (prev == null) return false;
    await _goToStep(prev);
    return true;
  }

  void _onNext() {
    final error = switch (widget.forms.signupStep) {
      SignupStep.displayName => validateDisplayName(widget.forms.displayName),
      SignupStep.username => validateUsername(widget.forms.signupUsername),
      SignupStep.birthday => validatePyreBirthday(widget.forms.birthday),
      SignupStep.password => validateSignupPassword(widget.forms.signupPassword),
    };
    if (error != null) {
      widget.forms.signupError = error;
      widget.onChanged();
      return;
    }

    final next = widget.forms.signupStep.next;
    if (next != null) {
      widget.forms.signupError = null;
      _goToStep(next);
      return;
    }
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PyreColors.ember,
      child: PageView(
        controller: _stepController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          widget.forms.signupStep = _steps[index];
          widget.onChanged();
        },
        children: [for (final step in _steps) _stepPage(step)],
      ),
    );
  }

  Widget _stepPage(SignupStep step) {
    final f = widget.forms;
    switch (step) {
      case SignupStep.displayName:
        return SignupQuestion(
          title: step.title,
          subtitle: step.subtitle,
          error: f.signupError,
          busy: f.signupBusy,
          nextEnabled: f.displayName.trim().isNotEmpty,
          onNext: _onNext,
          input: _field(
            controller: _displayNameController,
            hint: 'Your name',
            onChanged: (v) {
              f.displayName = v;
              f.signupError = null;
              widget.onChanged();
            },
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _onNext(),
            autofillHints: const [AutofillHints.name],
          ),
        );
      case SignupStep.username:
        return SignupQuestion(
          title: step.title,
          subtitle: step.subtitle,
          error: f.signupError,
          busy: f.signupBusy,
          nextEnabled: f.signupUsername.trim().isNotEmpty,
          onNext: _onNext,
          input: _field(
            controller: _usernameController,
            hint: 'username',
            onChanged: (v) {
              f.signupUsername = v;
              f.signupError = null;
              widget.onChanged();
            },
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _onNext(),
            autofillHints: const [AutofillHints.newUsername],
          ),
        );
      case SignupStep.birthday:
        return SignupQuestion(
          title: step.title,
          subtitle: step.subtitle,
          error: f.signupError,
          busy: f.signupBusy,
          nextEnabled: normalizeBirthdayInput(f.birthday) != null,
          onNext: _onNext,
          input: _field(
            controller: _birthdayController,
            hint: 'YYYY  MM  DD',
            onChanged: (v) {
              f.birthday = v;
              f.signupError = null;
              widget.onChanged();
            },
            keyboardType: TextInputType.number,
            inputFormatters: const [BirthdayInputFormatter()],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _onNext(),
            autofillHints: const [AutofillHints.birthday],
          ),
        );
      case SignupStep.password:
        return SignupQuestion(
          title: step.title,
          subtitle: step.subtitle,
          error: f.signupError,
          busy: f.signupBusy,
          nextEnabled: f.signupPassword.isNotEmpty,
          onNext: _onNext,
          input: _field(
            controller: _passwordController,
            hint: 'Password',
            onChanged: (v) {
              f.signupPassword = v;
              f.signupError = null;
              widget.onChanged();
            },
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onNext(),
            autofillHints: const [AutofillHints.newPassword],
          ),
        );
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
    bool autocorrect = true,
    bool enableSuggestions = true,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofillHints: autofillHints,
      style: const TextStyle(color: PyreColors.onPaper, fontSize: 18),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: PyreColors.hintOnPaper),
        filled: true,
        fillColor: PyreColors.paperDim,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: PyreColors.ink.withValues(alpha: 0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: PyreColors.ember, width: 1.6),
        ),
      ),
    );
  }
}
