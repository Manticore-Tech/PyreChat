import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/app/app_bootstrap.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/profile/appearance_screen.dart';
import 'package:pyrechat_flutter/screens/profile/sessions_screen.dart';
import 'package:pyrechat_flutter/services/chat_cache.dart';
import 'package:pyrechat_flutter/services/chat_draft_store.dart';
import 'package:pyrechat_flutter/services/profile_photo_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_notifications.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_external_links.dart';
import 'package:pyrechat_flutter/services/pyre_mls.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/user_image_picker.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/logout_dialog.dart';
import 'package:pyrechat_flutter/widgets/pyre_avatar.dart';
import 'package:pyrechat_flutter/widgets/pyre_glass_surface.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';
import 'package:pyrechat_flutter/widgets/recovery_key_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.user,
    this.onUserChanged,
  });

  final PyreUser user;
  final ValueChanged<PyreUser>? onUserChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _api = PyreApi();
  final _session = SessionStore();
  late PyreUser _user;
  bool _busy = false;
  bool _deleteBusy = false;
  bool _photoBusy = false;
  bool _quietModeSupported = false;
  PyreQuietModeLevel _quietModeLevel = PyreQuietModeLevel.off;
  bool _quietModeBusy = false;

  static const _absoluteQuietWarningKey =
      'absolute_quiet_warning_acknowledged_v1';

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    WidgetsBinding.instance.addObserver(this);
    _loadQuietMode();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.username != widget.user.username ||
        oldWidget.user.displayName != widget.user.displayName) {
      _user = widget.user;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadQuietMode();
    }
  }

  Future<void> _loadQuietMode() async {
    final quietMode = PyreQuietMode.instance;
    final supported = await quietMode.isSupported;
    final level = await quietMode.level;
    if (!mounted) return;
    setState(() {
      _quietModeSupported = supported;
      _quietModeLevel = level;
    });
  }

  Future<void> _setQuietModeLevel(PyreQuietModeLevel level) async {
    if (_quietModeBusy || !_quietModeSupported) return;

    setState(() => _quietModeBusy = true);
    try {
      final changed = await PyreQuietMode.instance.setLevel(level);
      if (!mounted) return;
      if (!changed && level != PyreQuietModeLevel.off) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update PyreChat notification quiet mode.'),
          ),
        );
      }
      await _loadQuietMode();
    } finally {
      if (mounted) setState(() => _quietModeBusy = false);
    }
  }

  Future<void> _setQuietModeEnabled(bool enabled) async {
    await _setQuietModeLevel(
      enabled ? PyreQuietModeLevel.quiet : PyreQuietModeLevel.off,
    );
  }

  Future<void> _setAbsoluteQuiet(bool enabled) async {
    if (_quietModeBusy || !_quietModeSupported) return;

    if (enabled) {
      final prefs = await SharedPreferences.getInstance();
      final acknowledged = prefs.getBool(_absoluteQuietWarningKey) ?? false;
      if (!acknowledged) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: PyreColors.paper,
                title: const Text(
                  'Enable Absolute Quiet?',
                  style: TextStyle(
                    color: PyreColors.onPaper,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                content: const Text(
                  'Absolute Quiet mutes PyreChat notifications even while the app is in the background. Calls, alarms, and notifications from other apps are not affected.',
                  style: TextStyle(color: PyreColors.onPaperMuted),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!confirmed) return;
        await prefs.setBool(_absoluteQuietWarningKey, true);
      }
    }

    await _setQuietModeLevel(
      enabled ? PyreQuietModeLevel.absolute : PyreQuietModeLevel.quiet,
    );
  }

  Future<void> _editIdentity() async {
    final displayController = TextEditingController(text: _user.displayName);
    final usernameController = TextEditingController(text: _user.username);
    final passwordController = TextEditingController();
    final adminHandleLocked =
        _user.username.trim().toLowerCase() == 'maximuspyre';
    var saving = false;
    String? error;

    final updated = await showDialog<PyreUser>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving) return;
            final displayName = displayController.text.trim();
            final username = usernameController.text.trim();
            final usernameMatch =
                RegExp(r'^[a-zA-Z0-9._]+').stringMatch(username);
            if (displayName.isEmpty) {
              setDialogState(() => error = 'Enter a display name.');
              return;
            }
            final usernameChanged =
                username.toLowerCase() != _user.username.trim().toLowerCase();
            if (usernameChanged && passwordController.text.isEmpty) {
              setDialogState(
                () => error = 'Enter your current password to change username.',
              );
              return;
            }
            if (username.length < 3 ||
                username.length > 24 ||
                usernameMatch != username) {
              setDialogState(
                () => error =
                    'Username must be 3–24 letters, numbers, dots, or underscores.',
              );
              return;
            }

            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final user = await PyreClient().updateIdentity(
                username: username,
                displayName: displayName,
                currentPassword: usernameChanged
                    ? passwordController.text
                    : null,
              );
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(user);
            } on PyreApiException catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                saving = false;
                error = e.message;
              });
            } catch (_) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                saving = false;
                error = 'Could not update your profile.';
              });
            }
          }

          return AlertDialog(
            backgroundColor: PyreColors.paper,
            title: const Text(
              'Edit profile',
              style: TextStyle(
                color: PyreColors.onPaper,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: displayController,
                    maxLength: 32,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    enabled: !adminHandleLocked,
                    maxLength: 24,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      helperText: adminHandleLocked
                          ? 'Admin username is fixed.'
                          : '3–24 letters, numbers, dots, or underscores.',
                    ),
                  ),
                  if (!adminHandleLocked) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!saving) save();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        helperText: 'Required only when changing your username.',
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: PyreColors.errorOnPaper,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    displayController.dispose();
    usernameController.dispose();
    passwordController.dispose();

    if (updated == null || !mounted) return;
    setState(() => _user = updated);
    widget.onUserChanged?.call(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated.')),
    );
  }

  Future<void> _rotateRecoveryKey() async {
    final passwordController = TextEditingController();
    var saving = false;
    String? error;

    final recoveryKey = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> rotate() async {
            if (saving) return;
            final password = passwordController.text;
            if (password.isEmpty) {
              setDialogState(() => error = 'Enter your current password.');
              return;
            }

            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final key = await PyreClient().rotateRecoveryKey(password);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(key);
            } on PyreApiException catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                saving = false;
                error = e.message;
              });
            } catch (_) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                saving = false;
                error = 'Could not replace your recovery key.';
              });
            }
          }

          return AlertDialog(
            backgroundColor: PyreColors.paper,
            title: const Text(
              'Replace recovery key?',
              style: TextStyle(
                color: PyreColors.onPaper,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your old recovery key will stop working immediately. Only continue if you are ready to save the new key somewhere safe.',
                    style: TextStyle(
                      color: PyreColors.onPaperMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!saving) rotate();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: PyreColors.errorOnPaper,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : rotate,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Replace key'),
              ),
            ],
          );
        },
      ),
    );

    passwordController.dispose();
    if (!mounted || recoveryKey == null || recoveryKey.isEmpty) return;
    await showRecoveryKeyDialog(
      context: context,
      recoveryKey: recoveryKey,
    );
  }

  Future<void> _changePhoto() async {
    if (_photoBusy) return;
    try {
      setState(() => _photoBusy = true);
      final bytes = await UserImagePicker.pick(UserImagePurpose.profile);
      if (bytes == null || !mounted) return;
      await ProfilePhotoPrefs.instance.setFor(_user.id, bytes);
      String message = 'Profile photo saved on this device.';
      try {
        await PyreClient().uploadProfilePhoto(bytes);
        message = 'Profile photo synced across PyreChat.';
      } on PyreApiException catch (error) {
        message = error.statusCode == 404
            ? 'Profile photo saved locally. Server sync needs the backend update.'
            : 'Profile photo saved locally. Sync failed: ${error.message}';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile photo: $error')),
      );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_deleteBusy || _busy) return;

    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    var submitting = false;
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (submitting) return;
            final password = passwordController.text;
            final confirmation = confirmationController.text.trim();
            if (password.isEmpty) {
              setDialogState(() => error = 'Enter your current password.');
              return;
            }
            if (confirmation != 'DELETE') {
              setDialogState(() => error = 'Type DELETE exactly to continue.');
              return;
            }

            setDialogState(() {
              submitting = true;
              error = null;
            });

            final token = await _session.token;
            if (token == null || token.isEmpty) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                submitting = false;
                error = 'Your session is no longer available. Sign in again.';
              });
              return;
            }

            try {
              await _api.deleteAccount(token: token, password: password);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(true);
            } on PyreApiException catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                submitting = false;
                error = e.message;
              });
            } catch (_) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                submitting = false;
                error = 'Could not delete your account.';
              });
            }
          }

          return AlertDialog(
            backgroundColor: PyreColors.paper,
            title: const Text(
              'Delete PyreChat account?',
              style: TextStyle(
                color: PyreColors.onPaper,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently deletes your PyreChat account and signs out every device. Your profile, private account data, and user-owned media/content are removed. Media cleanup may finish shortly after the account itself is deleted.',
                    style: TextStyle(
                      color: PyreColors.onPaperMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    autofocus: true,
                    autofillHints: const [AutofillHints.password],
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmationController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'Type DELETE',
                      helperText: 'This action cannot be undone.',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      label: 'Account deletion error: $error',
                      child: ExcludeSemantics(
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: PyreColors.errorOnPaper,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submitting ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Delete forever'),
              ),
            ],
          );
        },
      ),
    );

    passwordController.dispose();
    confirmationController.dispose();

    if (confirmed != true || !mounted) return;

    setState(() => _deleteBusy = true);
    try {
      await ChatCache.instance.clearUser(_user.id);
      await ProfilePhotoPrefs.instance.clearFor(_user.id);
      await PyreMlsProvisioner().deleteLocalIdentity(_user.id);
      await _session.clear();
      ChatDraftStore.instance.clearAll();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppBootstrap()),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;

    final shouldLogout = await confirmLogout(
      context,
      draftCount: ChatDraftStore.instance.draftCount,
    );
    if (!shouldLogout || !mounted) return;

    setState(() => _busy = true);

    final token = await _session.token;
    if (token != null) {
      try {
        await _api.logout(token: token);
      } catch (_) {
        // Clear local session even if the server call fails.
      }
    }
    await ChatCache.instance.clearUser(_user.id);
    await _session.clear();
    ChatDraftStore.instance.clearAll();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppBootstrap()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user.displayName.trim().isNotEmpty
        ? _user.displayName.trim()
        : _user.username.trim();
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PyreColors.night,
      body: PyreNightBackdrop(
        mood: PyreSurfaceMood.settings,
        showEmbers: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, top + 10, 18, 30),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back to profile',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: PyreColors.nightText,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: PyreColors.nightText,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.55,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PyreGlassSurface(
              tone: PyreGlassTone.standard,
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PyreAvatar(
                    user: _user,
                    size: 56,
                    showRing: true,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PyreColors.nightText,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${_user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PyreColors.nightMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Change profile photo',
                    onPressed: _photoBusy ? null : _changePhoto,
                    icon: _photoBusy
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PyreColors.emberGlow,
                            ),
                          )
                        : const Icon(
                            Icons.photo_camera_rounded,
                            color: PyreColors.emberGlow,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('ACCOUNT'),
            const SizedBox(height: 8),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.badge_outlined,
                  title: 'Name & username',
                  subtitle: 'Change how people find and recognize you.',
                  onTap: _editIdentity,
                  showChevron: true,
                ),
                const _Divider(),
                _SettingsRow(
                  icon: Icons.devices_outlined,
                  title: 'Signed-in devices',
                  subtitle: 'Review and sign out other PyreChat sessions.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SessionsScreen(),
                      ),
                    );
                  },
                  showChevron: true,
                ),
                const _Divider(),
                _SettingsRow(
                  icon: Icons.key_rounded,
                  title: 'Recovery key',
                  subtitle: 'Replace your recovery key if the old one is lost or exposed.',
                  onTap: _rotateRecoveryKey,
                  showChevron: true,
                ),
                const _Divider(),
                _SettingsRow(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete account',
                  subtitle:
                      'Permanently delete your PyreChat account, content, and sessions.',
                  onTap: _deleteBusy ? null : _deleteAccount,
                  showChevron: true,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('APPEARANCE'),
            const SizedBox(height: 8),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle:
                      'Choose your accent and personalize your Pyre.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AppearanceScreen(),
                      ),
                    );
                  },
                  showChevron: true,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('MESSAGING'),
            const SizedBox(height: 8),
            _SettingsGroup(
              children: [
                if (_quietModeSupported) ...[
                  _SettingsSwitchRow(
                    icon: Icons.notifications_paused_outlined,
                    title: 'Quiet while using PyreChat',
                    subtitle:
                        'Mute PyreChat notification banners while you are using the app.',
                    value: _quietModeLevel != PyreQuietModeLevel.off,
                    busy: _quietModeBusy,
                    onChanged: _setQuietModeEnabled,
                  ),
                  if (_quietModeLevel != PyreQuietModeLevel.off) ...[
                    const _Divider(),
                    _SettingsSwitchRow(
                      icon: Icons.do_not_disturb_on_total_silence_outlined,
                      title: 'Absolute Quiet',
                      subtitle:
                          'Mute PyreChat notifications even while the app is in the background.',
                      value: _quietModeLevel == PyreQuietModeLevel.absolute,
                      busy: _quietModeBusy,
                      onChanged: _setAbsoluteQuiet,
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('PRIVACY & SAFETY'),
            const SizedBox(height: 8),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  subtitle: 'See how PyreChat handles account and app data.',
                  onTap: () => PyreExternalLinks.open(
                    'https://chat.pyrearms.dev/privacy',
                  ),
                  showChevron: true,
                ),
                const _Divider(),
                _SettingsRow(
                  icon: Icons.gavel_outlined,
                  title: 'Terms',
                  subtitle: 'Review the current PyreChat Terms of Service.',
                  onTap: () => PyreExternalLinks.open(
                    'https://chat.pyrearms.dev/terms',
                  ),
                  showChevron: true,
                ),
                const _Divider(),
                _SettingsRow(
                  icon: Icons.support_agent_outlined,
                  title: 'Support',
                  subtitle: 'Get help with your PyreChat account or app.',
                  onTap: () => PyreExternalLinks.open(
                    'https://chat.pyrearms.dev/support',
                  ),
                  showChevron: true,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('SESSION'),
            const SizedBox(height: 8),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  subtitle: 'Sign out of PyreChat on this device.',
                  onTap: _busy ? null : _logout,
                  showChevron: false,
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PyreColors.emberGlow,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: PyreColors.nightMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.05,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PyreGlassSurface(
      tone: PyreGlassTone.standard,
      radius: 16,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    this.icon,
    this.asset,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = false,
  }) : assert(icon != null || asset != null);

  final IconData? icon;
  final String? asset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final leading = asset != null
        ? PyreIcon(asset: asset!, size: 22)
        : Icon(icon, size: 22, color: PyreColors.emberGlow);

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: title,
      hint: subtitle,
      child: ExcludeSemantics(
        child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 28, child: Center(child: leading)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: PyreColors.nightText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: PyreColors.nightMuted,
                        fontSize: 12.25,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: PyreColors.nightMuted,
                ),
              ],
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: Icon(icon, size: 22, color: PyreColors.emberGlow),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 12.25,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PyreColors.emberGlow,
              ),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 54,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}
