import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/profile/settings_screen.dart';
import 'package:pyrechat_flutter/screens/pyre/pyre_page_screen.dart';
import 'package:pyrechat_flutter/services/appearance_prefs.dart';
import 'package:pyrechat_flutter/services/profile_photo_prefs.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/user_image_picker.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/animated_pyre_fire.dart';
import 'package:pyrechat_flutter/widgets/pyre_avatar.dart';
import 'package:pyrechat_flutter/widgets/pyre_glass_surface.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    this.onUserChanged,
  });

  final PyreUser user;
  final ValueChanged<PyreUser>? onUserChanged;

  Future<void> _changeProfilePhoto(BuildContext context) async {
    try {
      final bytes = await UserImagePicker.pick(UserImagePurpose.profile);
      if (bytes == null || !context.mounted) return;
      await ProfilePhotoPrefs.instance.setFor(user.id, bytes);
      String message = 'Profile photo saved on this device.';
      try {
        await PyreClient().uploadProfilePhoto(bytes);
        message = 'Profile photo synced across PyreChat.';
      } on PyreApiException catch (error) {
        message = error.statusCode == 404
            ? 'Profile photo saved locally. Server sync needs the backend update.'
            : 'Profile photo saved locally. Sync failed: ${error.message}';
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile photo: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final name = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.username.trim();

    return PyreNightBackdrop(
      mood: PyreSurfaceMood.profile,
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, top + 16, 18, 116),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'You',
                  style: TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              _RoundAction(
                icon: Icons.settings_rounded,
                semanticLabel: 'Open settings',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        user: user,
                        onUserChanged: onUserChanged,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 26),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: PyreColors.emberHot.withValues(alpha: 0.22),
                        blurRadius: 42,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                PyreAvatar(
                  user: user,
                  size: 104,
                  showRing: true,
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Semantics(
                    button: true,
                    label: 'Change profile photo',
                    child: Tooltip(
                      message: 'Change profile photo',
                      child: Material(
                        color: PyreColors.nightCardStrong,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _changeProfilePhoto(context),
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: ExcludeSemantics(
                              child: Icon(
                                Icons.photo_camera_rounded,
                                color: AppearancePrefs.instance.accentColor,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PyreColors.nightText,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '@${user.username}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PyreColors.nightMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 26),
          PyreGlassSurface(
            tone: PyreGlassTone.strong,
            radius: 24,
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 6, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Pyre',
                          style: TextStyle(
                            color: PyreColors.nightText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your quiet place for moments, mail, and people you actually know.',
                          style: TextStyle(
                            color: PyreColors.nightMuted,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No streaks · no score',
                          style: TextStyle(
                            color: PyreColors.emberGlow.withValues(alpha: 0.95),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 132,
                  child: Center(
                    child: AnimatedPyreFire(
                      size: 130,
                      seed: user.id.hashCode.abs(),
                      intensity: 0.88,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProfileMenuCard(
            children: [
              _ProfileRow(
                icon: Icons.local_fire_department_outlined,
                title: 'My Pyre',
                subtitle: 'Your private space and moments',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PyrePageScreen(user: user),
                    ),
                  );
                },
              ),
              const _Divider(),
              _ProfileRow(
                icon: Icons.settings_rounded,
                title: 'Settings',
                subtitle: 'Account, notifications, privacy',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        user: user,
                        onUserChanged: onUserChanged,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: ExcludeSemantics(
                  child: Icon(
                    icon,
                    color: PyreColors.nightText,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PyreGlassSurface(
      tone: PyreGlassTone.standard,
      radius: 22,
      padding: EdgeInsets.zero,
      shadow: false,
      child: Column(children: children),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PyreColors.ember.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: PyreColors.emberGlow,
                  size: 21,
                ),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PyreColors.nightMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PyreColors.nightMuted,
              ),
            ],
          ),
        ),
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
