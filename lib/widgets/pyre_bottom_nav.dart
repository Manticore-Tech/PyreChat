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
    (icon: PyreIcons.chat, label: 'Chats'),
    (icon: PyreIcons.flame, label: 'Pyre'),
    (icon: PyreIcons.camera, label: 'Camera'),
    (icon: PyreIcons.profile, label: 'You'),
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
            final pyre = index == 1;
            return Expanded(
              child: _NavItem(
                asset: item.icon,
                label: item.label,
                selected: selected,
                pyre: pyre,
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
    required this.pyre,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final bool pyre;
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
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          decoration: BoxDecoration(
            color: selected && !pyre
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: PyreMotion.standard,
                curve: PyreMotion.enter,
                width: pyre ? 38 : 30,
                height: pyre ? 38 : 30,
                alignment: Alignment.center,
                decoration: pyre
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: selected
                              ? const [
                                  Color(0xFFFFA14A),
                                  Color(0xFFFF5B27),
                                  Color(0xFFD83A2D),
                                ]
                              : [
                                  PyreColors.ember.withValues(alpha: 0.22),
                                  PyreColors.emberDeep.withValues(alpha: 0.18),
                                ],
                        ),
                        border: Border.all(
                          color: selected
                              ? PyreColors.emberGold.withValues(alpha: 0.86)
                              : PyreColors.emberGlow.withValues(alpha: 0.18),
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: PyreColors.emberHot.withValues(alpha: 0.42),
                                  blurRadius: 18,
                                  spreadRadius: -2,
                                ),
                              ]
                            : null,
                      )
                    : null,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    selected
                        ? (pyre ? PyreColors.nightText : PyreColors.emberGlow)
                        : PyreColors.nightMuted,
                    BlendMode.srcIn,
                  ),
                  child: PyreIcon(
                    asset: asset,
                    size: pyre ? 22 : 22,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? (pyre ? PyreColors.emberGlow : PyreColors.nightText)
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
