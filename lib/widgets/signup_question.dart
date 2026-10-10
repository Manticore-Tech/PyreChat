import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_warm_backdrop.dart';

class SignupQuestion extends StatelessWidget {
  const SignupQuestion({
    super.key,
    required this.title,
    this.subtitle,
    required this.input,
    required this.onNext,
    this.nextEnabled = true,
    this.busy = false,
    this.error,
  });

  final String title;
  final String? subtitle;
  final Widget input;
  final VoidCallback onNext;
  final bool nextEnabled;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return PyreWarmBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 56).clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                      decoration: BoxDecoration(
                        color: PyreColors.paper.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: PyreColors.paper.withValues(alpha: 0.46),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PyreColors.ink.withValues(alpha: 0.10),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.06,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.75,
                              color: PyreColors.ink,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 9),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                color: PyreColors.onPaperMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (error != null && error!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: PyreColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Semantics(
                                liveRegion: true,
                                label: 'Sign up error: $error',
                                child: ExcludeSemantics(
                                  child: Text(
                                    error!,
                                    style: const TextStyle(
                                      color: PyreColors.errorOnPaper,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 26),
                          input,
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed:
                                nextEnabled && !busy ? onNext : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: PyreColors.ink,
                              foregroundColor: PyreColors.paper,
                              disabledBackgroundColor:
                                  PyreColors.ink.withValues(alpha: 0.14),
                              disabledForegroundColor:
                                  PyreColors.ink.withValues(alpha: 0.36),
                              minimumSize: const Size.fromHeight(56),
                            ),
                            iconAlignment: IconAlignment.end,
                            icon: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: PyreColors.paper,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(busy ? 'Please wait…' : 'Continue'),
                          ),
                        ],
                      ),
                    ),
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

