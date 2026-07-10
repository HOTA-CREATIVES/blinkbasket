import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDark ? AppColors.bgDark : AppColors.bgLight,
      child: SafeArea(
        child: child,
      ),
    );
  }
}
