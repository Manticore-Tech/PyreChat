import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_motion.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';

class PyreBottomNav extends StatelessWidget {
  const PyreBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (
      inactive: PyreIcons.navChatInactive,
      active: PyreIcons.navChatActive,
      label: 'Chats',
    ),
    (
      inactive: PyreIcons.navPyreInactive,
      active: PyreIcons.navPyreActive,
      label: 'Pyre',
    ),
    (
      inactive: PyreIcons.navCameraInactive,
      active: PyreIcons.navCameraActive,
      label: 'Camera',
    ),
    (
      inactive: PyreIcons.navProfileInactive,
      active: PyreIcons.navProfileActive,
      label: 'You',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extraHeight = ((textScale - 1).clamp(0.0, 0.8)) * 28;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 78 + extraHeight,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xF20E1116),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: PyreColors.ember.withValues(alpha: 0.08),
              blurRadius: 26,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = selectedIndex == index;
            return Expanded(
              child: _NavItem(
                asset: selected ? item.active : item.inactive,
                label: item.label,
                selected: selected,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: PyreMotion.standard,
          curve: PyreMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.045)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: PyreMotion.standard,
                curve: PyreMotion.enter,
                width: selected ? 35 : 31,
                height: selected ? 35 : 31,
                alignment: Alignment.center,
                child: PyreIcon(
                  asset: asset,
                  size: selected ? 35 : 31,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? PyreColors.emberGlow
                      : PyreColors.nightMuted,
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
