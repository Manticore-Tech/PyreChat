import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/animated_pyre_fire.dart';
import 'package:pyrechat_flutter/widgets/pyre_avatar.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class PyrePageScreen extends StatelessWidget {
  const PyrePageScreen({
    super.key,
    required this.user,
  });

  final PyreUser user;

  String get _displayName {
    final value = user.displayName.trim();
    return value.isEmpty ? user.username : value;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final seed = user.id.hashCode.abs();

    return PyreNightBackdrop(
      mood: PyreNightMood.sunset,
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, top + 16, 18, 118),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Pyre',
                  style: TextStyle(
                    color: PyreColors.nightText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const _QuietBadge(),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: AnimatedPyreFire(
                    size: 250,
                    seed: seed,
                    intensity: 1.04,
                  ),
                ),
                PyreAvatar(
                  user: user,
                  size: 68,
                  showRing: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PyreColors.nightText,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '@${user.username}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PyreColors.nightMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A quiet place people can visit when they want to.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD5CBC4),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 26),
          const _PyreInfoCard(
            icon: Icons.photo_library_outlined,
            title: 'Moments',
            body:
                'Photos people leave at your fire will live here. No streaks, no score, no pressure.',
          ),
          const SizedBox(height: 10),
          const _PyreInfoCard(
            icon: Icons.mail_outline_rounded,
            title: 'Mail',
            body:
                'Quiet, deliberate messages are part of the Pyre direction. Persistence is not wired in this alpha yet.',
          ),
          const SizedBox(height: 10),
          const _PyreInfoCard(
            icon: Icons.forum_outlined,
            title: 'Chat room',
            body:
                'Direct chat remains the realtime conversation layer for alpha.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: PyreColors.emberGlow,
                  size: 20,
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Pyre visits do not create “come back” notifications. Direct messages can notify you, and each conversation can be muted independently.',
                    style: TextStyle(
                      color: PyreColors.nightMuted,
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
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

class _QuietBadge extends StatelessWidget {
  const _QuietBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.nights_stay_outlined,
            color: PyreColors.emberGlow,
            size: 14,
          ),
          SizedBox(width: 6),
          Text(
            'Quiet by design',
            style: TextStyle(
              color: PyreColors.nightText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PyreInfoCard extends StatelessWidget {
  const _PyreInfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: PyreColors.nightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.065),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PyreColors.ember.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: PyreColors.emberGlow, size: 21),
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
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 12.5,
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
