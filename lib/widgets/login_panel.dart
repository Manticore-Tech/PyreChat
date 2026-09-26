import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

class LoginPanel extends StatelessWidget {
  const LoginPanel({
    super.key,
    required this.username,
    required this.password,
    required this.onUsernameChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
    required this.busy,
    this.error,
  });

  final String username;
  final String password;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final canSubmit = username.trim().isNotEmpty && password.isNotEmpty && !busy;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            decoration: BoxDecoration(
              color: PyreColors.paper.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: PyreColors.ink.withValues(alpha: 0.055),
              ),
              boxShadow: [
                BoxShadow(
                  color: PyreColors.ink.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: _LoginEyebrow(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PyreColors.ink,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Come back to your people.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PyreColors.onPaperMuted,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    onChanged: onUsernameChanged,
                    style: const TextStyle(
                      color: PyreColors.onPaper,
                      fontWeight: FontWeight.w600,
                    ),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: onPasswordChanged,
                    obscureText: true,
                    style: const TextStyle(
                      color: PyreColors.onPaper,
                      fontWeight: FontWeight.w600,
                    ),
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (canSubmit) onSubmit();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  if (error != null && error!.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: PyreColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: PyreColors.errorOnPaper,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: canSubmit ? onSubmit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: PyreColors.ink,
                      foregroundColor: PyreColors.paper,
                      disabledBackgroundColor:
                          PyreColors.ink.withValues(alpha: 0.14),
                      disabledForegroundColor:
                          PyreColors.ink.withValues(alpha: 0.38),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: PyreColors.paper,
                            ),
                          )
                        : const Text('Log in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginEyebrow extends StatelessWidget {
  const _LoginEyebrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PyreColors.emberWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'BACK TO THE FIRE',
        style: TextStyle(
          color: PyreColors.emberDeep,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
