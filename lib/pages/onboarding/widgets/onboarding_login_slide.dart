import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/login_panel.dart';
import 'package:pyrechat_flutter/widgets/pyre_logo.dart';
import 'package:pyrechat_flutter/widgets/pyre_warm_backdrop.dart';

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
    final flame = MediaQuery.sizeOf(context).shortestSide * 0.24;

    return PyreWarmBackdrop(
      light: true,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
            final compactFlame = keyboardOpen
                ? flame.clamp(54.0, 76.0)
                : flame.clamp(78.0, 112.0);

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: keyboardOpen ? 10 : 28),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: compactFlame + 42,
                            height: compactFlame + 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: PyreColors.emberWash.withValues(alpha: 0.72),
                            ),
                          ),
                          PyreLogo(size: compactFlame),
                        ],
                      ),
                      SizedBox(height: keyboardOpen ? 14 : 26),
                      const Spacer(),
                      LoginPanel(
                        username: username,
                        password: password,
                        onUsernameChanged: onUsernameChanged,
                        onPasswordChanged: onPasswordChanged,
                        onSubmit: onSubmit,
                        busy: busy,
                        error: error,
                      ),
                      const Spacer(flex: 2),
                      SizedBox(height: keyboardOpen ? 14 : 28),
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
