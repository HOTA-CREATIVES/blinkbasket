import 'package:flutter/material.dart';
import 'app_tokens.dart';

/// App-wide page transitions, built purely from Flutter's own animation
/// primitives (`Tween`/`FadeTransition`/`SlideTransition`) — no external
/// package — so every push in the app shares one motion language instead of
/// each screen falling back to the default `MaterialPageRoute`.
class AppPageRoute {
  AppPageRoute._();

  /// Cross-fade, for lateral/tab-like navigation (e.g. Home -> Search,
  /// Home -> Cart) where the destination doesn't feel like a "deeper" push.
  static Route<T> fadeThrough<T>(WidgetBuilder builder, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: AppTokens.normal,
      reverseTransitionDuration: AppTokens.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  /// Slide-up + fade, for pushes that feel like a "sheet"/deeper drill-in
  /// (e.g. product details, task detail, settings screens).
  static Route<T> slideUp<T>(WidgetBuilder builder, {RouteSettings? settings}) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: AppTokens.normal,
      reverseTransitionDuration: AppTokens.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
