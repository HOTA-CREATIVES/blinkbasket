import 'package:flutter/material.dart';
import '../app_tokens.dart';

class CategoryIconRail extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final void Function(String category) onSelect;

  const CategoryIconRail({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  IconData _iconForCategory(String name) {
    switch (name.toLowerCase()) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'fruits & vegetables':
        return Icons.eco_rounded;
      case 'dairy & eggs':
        return Icons.egg_alt_rounded;
      case 'bakery':
        return Icons.bakery_dining_rounded;
      case 'medicines':
        return Icons.medical_services_rounded;
      case 'snacks':
        return Icons.cookie_rounded;
      case 'beverages':
        return Icons.local_drink_rounded;
      case 'household':
        return Icons.home_work_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.toLowerCase() == selectedCategory.toLowerCase();

          return GestureDetector(
            onTap: () => onSelect(category),
            child: Container(
              margin: const EdgeInsets.only(right: AppTokens.s16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppTokens.fast,
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(AppTokens.s12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary
                          : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? scheme.primary : scheme.outlineVariant,
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      _iconForCategory(category),
                      color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
