import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/animated_pyre_fire.dart';
import 'package:pyrechat_flutter/widgets/pyre_glass_surface.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class FriendPyreScreen extends StatelessWidget {
  const FriendPyreScreen({
    super.key,
    required this.displayName,
    required this.seed,
    this.onLeavePhoto,
  });

  final String displayName;
  final int seed;
  final VoidCallback? onLeavePhoto;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().characters.first.toUpperCase();

    return Scaffold(
      backgroundColor: PyreColors.night,
      body: PyreNightBackdrop(
        mood: PyreSurfaceMood.friendPyre,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Friend’s Pyre',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PyreColors.nightText,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const _CircleButton(
                    icon: Icons.more_horiz_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFA452),
                        Color(0xFFE54A2F),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: PyreColors.nightText,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PyreColors.nightText,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'A quieter place to share, anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD7CCC5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Center(
                child: AnimatedPyreFire(
                  size: 278,
                  seed: seed.abs(),
                  intensity: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              _ActionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Leave a photo',
                subtitle: 'Open Camera and send a moment directly.',
                enabled: onLeavePhoto != null,
                onTap: () {
                  Navigator.of(context).pop();
                  onLeavePhoto?.call();
                },
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: Icons.forum_outlined,
                title: 'Chat room',
                subtitle: 'Go back to your realtime conversation.',
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 10),
              const _ActionCard(
                icon: Icons.mail_outline_rounded,
                title: 'Mail',
                subtitle: 'Quiet mail is not persisted in this alpha yet.',
                enabled: false,
              ),
              const SizedBox(height: 18),
              const Text(
                'No visit notifications. No streak. No score.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PyreColors.nightMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: PyreGlassSurface(
        tone: PyreGlassTone.strong,
        radius: 22,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PyreColors.ember.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: PyreColors.emberGlow,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: PyreColors.nightText,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: PyreColors.nightMuted,
                          fontSize: 12.5,
                          height: 1.25,
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
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: PyreColors.nightText,
            size: 22,
          ),
        ),
      ),
    );
  }
}
