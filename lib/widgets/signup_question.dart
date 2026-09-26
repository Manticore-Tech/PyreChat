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
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: PyreColors.paper.withValues(alpha: 0.46),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PyreColors.ink.withValues(alpha: 0.10),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: _SignupEyebrow(),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 34,
                              height: 1.02,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
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
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  color: PyreColors.errorOnPaper,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
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
                            label: Text(busy ? 'One sec…' : 'Continue'),
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

class _SignupEyebrow extends StatelessWidget {
  const _SignupEyebrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PyreColors.emberWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'CREATE YOUR PYRE',
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
