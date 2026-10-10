import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/widgets/pyre_campfire_backdrop.dart';

class OnboardingChoiceSlide extends StatefulWidget {
  const OnboardingChoiceSlide({
    super.key,
    required this.onLogin,
    required this.onSignup,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  State<OnboardingChoiceSlide> createState() => OnboardingChoiceSlideState();
}

class OnboardingChoiceSlideState extends State<OnboardingChoiceSlide> {
  Future<bool> collapseToIdle() async => false;

  @override
  Widget build(BuildContext context) {
    return PyreCampfireBackdrop(
      dim: 0.06,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 620;
              return Column(
                children: [
                  const Spacer(flex: 2),
                  Column(
                    children: [
                      Text(
                        'Pyre Social',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 36 : 42,
                          height: .98,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.45,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 18,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Chats, Pyres, and your people.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                          fontSize: compact ? 13 : 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .1,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            widget.onSignup();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6F2C),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Create account'),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            widget.onLogin();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: .38),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: .18),
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Log in'),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'By continuing, you agree to Pyre Social\'s Terms and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .52),
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
