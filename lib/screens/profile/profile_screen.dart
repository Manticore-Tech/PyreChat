import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/screens/profile/settings_screen.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/animated_pyre_fire.dart';
import 'package:pyrechat_flutter/widgets/pyre_avatar.dart';
import 'package:pyrechat_flutter/widgets/pyre_glass_surface.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final PyreUser user;

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
                asset: PyreIcons.actionSettings,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(user: user),
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
                asset: PyreIcons.actionGallery,
                title: 'Media',
                subtitle: 'Coming after the alpha',
                enabled: false,
              ),
              const _Divider(),
              _ProfileRow(
                asset: PyreIcons.actionGroups,
                title: 'Friends',
                subtitle: 'Coming after the alpha',
                enabled: false,
              ),
              const _Divider(),
              _ProfileRow(
                asset: PyreIcons.actionSettings,
                title: 'Settings',
                subtitle: 'Account, notifications, privacy',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(user: user),
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
    required this.asset,
    required this.onTap,
  });

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: PyreIcon(asset: asset, size: 44),
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
    required this.asset,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final String asset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: PyreIcon(asset: asset, size: 38),
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
              if (enabled)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PyreColors.nightMuted,
                )
              else
                const Text(
                  'Soon',
                  style: TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
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
