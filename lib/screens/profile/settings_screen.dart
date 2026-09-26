import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/app/app_bootstrap.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/chat_draft_store.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/session_store.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/logout_dialog.dart';
import 'package:pyrechat_flutter/widgets/pyre_avatar.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.user});

  final PyreUser user;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = PyreApi();
  final _session = SessionStore();
  bool _busy = false;

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
    final name = widget.user.displayName.trim().isNotEmpty
        ? widget.user.displayName.trim()
        : widget.user.username.trim();
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PyreColors.night,
      body: PyreNightBackdrop(
        mood: PyreNightMood.night,
        showEmbers: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, top + 10, 18, 30),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PyreColors.nightCardStrong,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  PyreAvatar(
                    user: widget.user,
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
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${widget.user.username}',
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
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('MESSAGING'),
            const SizedBox(height: 8),
            const _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle:
                      'Direct messages can notify you. Mute any conversation from its chat menu.',
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.push_pin_outlined,
                  title: 'Conversation order',
                  subtitle:
                      'Long-press a chat to pin it to the top or intentionally send it to the bottom.',
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('PYRE'),
            const SizedBox(height: 8),
            const _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Quiet by design',
                  subtitle:
                      'Visiting a Pyre does not create streaks, scores, or “come back” notifications.',
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('PRIVACY & SAFETY'),
            const SizedBox(height: 8),
            const _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  title: 'Account safety',
                  subtitle:
                      'Recovery and secure Android session storage are active in this alpha.',
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.visibility_off_outlined,
                  title: 'Lock-screen previews',
                  subtitle:
                      'Notification previews stay generic instead of exposing private message text.',
                ),
              ],
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _busy ? null : _logout,
              style: FilledButton.styleFrom(
                backgroundColor: PyreColors.emberHot,
                foregroundColor: PyreColors.nightText,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PyreColors.nightText,
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(_busy ? 'Logging out…' : 'Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: PyreColors.nightMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.15,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PyreColors.nightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PyreColors.ember.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: PyreColors.emberGlow, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
      indent: 64,
      endIndent: 14,
      color: Colors.white.withValues(alpha: 0.055),
    );
  }
}
