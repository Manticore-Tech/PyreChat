import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/capture/custom_lens.dart';
import 'package:pyrechat_flutter/capture/pyre_grades.dart';
import 'package:pyrechat_flutter/capture/pyre_lenses.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_icon.dart';

/// Snapchat-style minimal camera HUD — overlays only, no chrome rows.
class CaptureHud extends StatelessWidget {
  const CaptureHud({
    super.key,
    required this.lens,
    required this.customLens,
    required this.customLenses,
    required this.grade,
    required this.busy,
    required this.lastShot,
    required this.onLensSelected,
    required this.onCustomLensSelected,
    required this.onOpenStudio,
    required this.onGradeSelected,
    required this.onCapture,
    required this.onFlip,
    this.onTapLastShot,
    this.onGoChats,
    this.onGoProfile,
  });

  final PyreLensId lens;
  final CustomLensDef? customLens;
  final List<CustomLensDef> customLenses;
  final PyreGradeId grade;
  final bool busy;
  final Uint8List? lastShot;
  final ValueChanged<PyreLensId> onLensSelected;
  final ValueChanged<CustomLensDef?> onCustomLensSelected;
  final VoidCallback onOpenStudio;
  final ValueChanged<PyreGradeId> onGradeSelected;
  final VoidCallback onCapture;
  final VoidCallback onFlip;
  final VoidCallback? onTapLastShot;
  final VoidCallback? onGoChats;
  final VoidCallback? onGoProfile;

  void _openGradeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PyreColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Color',
                  style: TextStyle(
                    color: PyreColors.paper,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: PyreGrades.all.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final g = PyreGrades.all[i];
                      final on = g.id == grade;
                      return GestureDetector(
                        onTap: () {
                          onGradeSelected(g.id);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: on ? PyreColors.ember : PyreColors.ink,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: on ? PyreColors.ember : PyreColors.mute.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            g.label,
                            style: TextStyle(
                              color: on ? PyreColors.paper : PyreColors.mute,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final lensItems = <_LensCarouselItem>[
      for (final l in PyreLenses.all)
        _LensCarouselItem.builtin(l.id, l.label, PyreLenses.iconAsset(l.id)),
      for (final c in customLenses)
        _LensCarouselItem.custom(c),
      const _LensCarouselItem.studio(),
    ];

    final selectedIndex = _selectedIndex(lensItems);

    return Stack(
      children: [
        // Top controls
        Positioned(
          top: top + 6,
          left: 12,
          right: 12,
          child: Row(
            children: [
              if (lastShot != null)
                GestureDetector(
                  onTap: onTapLastShot,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(lastShot!, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                )
              else
                const SizedBox(width: 44),
              const Spacer(),
              _HudIconButton(
                icon: 'assets/icons/sliders.png',
                onTap: () => _openGradeSheet(context),
                active: grade != PyreGradeId.none,
              ),
              const SizedBox(width: 8),
              _HudIconButton(icon: PyreIcons.refresh, onTap: onFlip),
            ],
          ),
        ),

        // Bottom HUD
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom + 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 76,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: lensItems.length,
                      itemBuilder: (context, i) {
                        final item = lensItems[i];
                        final selected = i == selectedIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _LensThumbnail(
                            item: item,
                            selected: selected,
                            onTap: () => _onLensTap(item),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: busy ? null : onCapture,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: busy ? PyreColors.mute : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _CornerNav(label: 'Chats', onTap: onGoChats),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _CornerNav(label: 'Profile', onTap: onGoProfile),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _selectedIndex(List<_LensCarouselItem> items) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.builtinId != null && item.builtinId == lens && customLens == null) return i;
      if (item.custom != null && customLens?.id == item.custom!.id) return i;
    }
    return 0;
  }

  void _onLensTap(_LensCarouselItem item) {
    if (item.isStudio) {
      onOpenStudio();
      return;
    }
    if (item.custom != null) {
      onCustomLensSelected(item.custom);
      return;
    }
    if (item.builtinId != null) {
      onLensSelected(item.builtinId!);
    }
  }
}

class _LensCarouselItem {
  const _LensCarouselItem._({
    this.builtinId,
    this.label,
    this.iconAsset,
    this.custom,
    this.isStudio = false,
  });

  const _LensCarouselItem.builtin(PyreLensId id, String label, String? icon)
      : this._(builtinId: id, label: label, iconAsset: icon);

  _LensCarouselItem.custom(CustomLensDef lens) : this._(custom: lens, label: lens.name);

  const _LensCarouselItem.studio() : this._(isStudio: true, label: 'Make');

  final PyreLensId? builtinId;
  final String? label;
  final String? iconAsset;
  final CustomLensDef? custom;
  final bool isStudio;
}

class _LensThumbnail extends StatelessWidget {
  const _LensThumbnail({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _LensCarouselItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 58.0 : 48.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? PyreColors.ember : Colors.white.withValues(alpha: 0.45),
            width: selected ? 2.5 : 1.5,
          ),
          color: Colors.black.withValues(alpha: 0.35),
        ),
        child: Center(
          child: _thumbContent(),
        ),
      ),
    );
  }

  Widget _thumbContent() {
    if (item.isStudio) {
      return const PyreIcon(asset: PyreIcons.flamePlus, size: 26);
    }
    if (item.builtinId == PyreLensId.none) {
      return Text(
        'Off',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    if (item.iconAsset != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Image.asset(item.iconAsset!, fit: BoxFit.contain),
      );
    }
    if (item.custom != null) {
      final asset = item.custom!.elements.isNotEmpty ? item.custom!.elements.first.asset : null;
      if (asset != null) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(asset, fit: BoxFit.contain),
        );
      }
      return Text(
        item.custom!.name.characters.first.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      );
    }
    return const SizedBox.shrink();
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PyreIcon(asset: icon, size: 24),
              if (active)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PyreColors.ember,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerNav extends StatelessWidget {
  const _CornerNav({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.92),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      child: Text(label),
    );
  }
}
