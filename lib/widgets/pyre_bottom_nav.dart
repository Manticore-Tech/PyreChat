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
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      brandAsset: null,
      label: 'Chats',
    ),
    (
      icon: Icons.photo_camera_outlined,
      selectedIcon: Icons.photo_camera_rounded,
      brandAsset: null,
      label: 'Camera',
    ),
    (
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      brandAsset: null,
      label: 'You',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extraHeight = ((textScale - 1).clamp(0.0, 0.8)) * 28;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      height: 66 + bottomInset + extraHeight,
      padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset + 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D11),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = selectedIndex == index;
          return Expanded(
            child: _NavItem(
              icon: item.icon,
              selectedIcon: item.selectedIcon,
              brandAsset: item.brandAsset,
              label: item.label,
              position: index + 1,
              total: _items.length,
              selected: selected,
              onTap: () => onSelected(index),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.icon,
    this.selectedIcon,
    this.brandAsset,
    required this.label,
    required this.position,
    required this.total,
    required this.selected,
    required this.onTap,
  }) : assert(icon != null || brandAsset != null);

  final IconData? icon;
  final IconData? selectedIcon;
  final String? brandAsset;
  final String label;
  final int position;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      label: [label, 'tab', position.toString(), 'of', total.toString()].join(' '),
      hint: selected ? 'Current tab' : 'Switch tabs',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: PyreMotion.standard,
          curve: PyreMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: PyreMotion.standard,
                curve: PyreMotion.enter,
                width: 31,
                height: 31,
                alignment: Alignment.center,
                child: brandAsset != null
                    ? PyreIcon(
                        asset: brandAsset!,
                        size: selected ? 28 : 25,
                        opacity: selected ? 1 : 0.62,
                      )
                    : Icon(
                        selected ? (selectedIcon ?? icon) : icon,
                        size: selected ? 25 : 23,
                        color: selected ? accent : PyreColors.nightMuted,
                      ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? accent
                      : PyreColors.nightMuted,
                  fontSize: 10,
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
