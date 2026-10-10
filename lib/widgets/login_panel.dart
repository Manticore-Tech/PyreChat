import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

class LoginPanel extends StatefulWidget {
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
  State<LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<LoginPanel> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;

  bool get _canSubmit =>
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !widget.busy;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    _passwordController = TextEditingController(text: widget.password);
  }

  @override
  void didUpdateWidget(covariant LoginPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(_usernameController, oldWidget.username, widget.username);
    _syncController(_passwordController, oldWidget.password, widget.password);
  }

  void _syncController(
    TextEditingController controller,
    String oldValue,
    String newValue,
  ) {
    if (newValue == oldValue || controller.text == newValue) return;
    controller.value = TextEditingValue(
      text: newValue,
      selection: TextSelection.collapsed(offset: newValue.length),
    );
  }

  void _onUsernameChanged(String value) {
    widget.onUsernameChanged(value);
    if (mounted) setState(() {});
  }

  void _onPasswordChanged(String value) {
    widget.onPasswordChanged(value);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Sign in to your account.',
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
                    controller: _usernameController,
                    onChanged: _onUsernameChanged,
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
                    controller: _passwordController,
                    onChanged: _onPasswordChanged,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      color: PyreColors.onPaper,
                      fontWeight: FontWeight.w600,
                    ),
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (_canSubmit) widget.onSubmit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (widget.error != null && widget.error!.isNotEmpty) ...[
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
                      child: Semantics(
                        liveRegion: true,
                        label: 'Login error: ${widget.error!}',
                        child: ExcludeSemantics(
                          child: Text(
                            widget.error!,
                            textAlign: TextAlign.center,
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
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _canSubmit ? widget.onSubmit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: PyreColors.ink,
                      foregroundColor: PyreColors.paper,
                      disabledBackgroundColor:
                          PyreColors.ink.withValues(alpha: 0.14),
                      disabledForegroundColor:
                          PyreColors.ink.withValues(alpha: 0.38),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: widget.busy
                        ? Semantics(
                            liveRegion: true,
                            label: 'Logging in',
                            child: ExcludeSemantics(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: PyreColors.paper,
                                ),
                              ),
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

