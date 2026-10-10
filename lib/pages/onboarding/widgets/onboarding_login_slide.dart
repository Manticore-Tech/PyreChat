import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/widgets/login_panel.dart';
import 'package:pyrechat_flutter/widgets/pyre_campfire_backdrop.dart';

/// A single stable sign-in surface. The previous keyboard-open layout removed
/// header/spacer siblings above LoginPanel, recreating its text fields and
/// dropping focus as the browser keyboard resized the viewport.
class OnboardingLoginSlide extends StatelessWidget {
  const OnboardingLoginSlide({
    super.key,
    required this.username,
    required this.password,
    required this.onUsernameChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
    required this.busy,
    this.error,
    this.onBack,
  });

  final String username;
  final String password;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;
  final VoidCallback? onBack;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return PyreCampfireBackdrop(
      dim: 0.24,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 36).clamp(0.0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoginPanel(
                      username: username,
                      password: password,
                      onUsernameChanged: onUsernameChanged,
                      onPasswordChanged: onPasswordChanged,
                      onSubmit: onSubmit,
                      busy: busy,
                      error: error,
                    ),
                    if (onBack != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: onBack,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 44),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
