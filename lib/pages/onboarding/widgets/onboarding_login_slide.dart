import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/widgets/login_panel.dart';
import 'package:pyrechat_flutter/widgets/pyre_campfire_backdrop.dart';

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
    return PyreCampfireBackdrop(
      dim: 0.18,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                top: keyboardOpen ? 12 : 28,
                bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      (keyboardOpen ? MediaQuery.viewInsetsOf(context).bottom : 0),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      if (!keyboardOpen) ...[
                        const Spacer(),
                        const Text(
                          'PyreChat',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            height: .96,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Back to the fire.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .72),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(flex: 2),
                      ] else
                        const SizedBox(height: 8),
                      LoginPanel(
                        username: username,
                        password: password,
                        onUsernameChanged: onUsernameChanged,
                        onPasswordChanged: onPasswordChanged,
                        onSubmit: onSubmit,
                        busy: busy,
                        error: error,
                      ),
                      if (!keyboardOpen) const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
