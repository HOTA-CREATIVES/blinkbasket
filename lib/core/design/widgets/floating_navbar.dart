import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FloatingNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int badgeCount;

  const FloatingNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class FloatingNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;

  const FloatingNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = max(8.0, MediaQuery.of(context).padding.bottom);

    // Calculate responsive width ~88% of screen width, bounded for tablets
    final navWidth = min(screenWidth * 0.88, 440.0);

    return SizedBox(
      height: 60 + bottomPadding + 8,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(bottom: bottomPadding, top: 4),
        alignment: Alignment.center,
        child: Container(
          width: navWidth,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.08),
                blurRadius: 8,
                spreadRadius: -2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: Semantics(
                    selected: isSelected,
                    label: item.label,
                    button: true,
                    child: InkWell(
                      onTap: () => onTap(index),
                      borderRadius: BorderRadius.circular(26),
                      splashColor: scheme.primary.withValues(alpha: 0.1),
                      highlightColor: Colors.transparent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildIcon(context, item, isSelected),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ), // Row
          ), // Padding
        ), // inner Container
      ), // BackdropFilter
    ), // ClipRRect
  ), // outer pill Container
), // alignment Container
); // SizedBox
}

  Widget _buildIcon(BuildContext context, FloatingNavItem item, bool isSelected) {
    final scheme = Theme.of(context).colorScheme;
    final iconData = (isSelected && item.activeIcon != null) ? item.activeIcon! : item.icon;

    Widget iconWidget = AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Icon(
        iconData,
        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
        size: 22,
      ),
    );

    if (item.badgeCount > 0) {
      iconWidget = Badge(
        label: Text(
          '${item.badgeCount}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        ),
        backgroundColor: scheme.error,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}
