import 'package:flutter/material.dart';
import '../app_tokens.dart';

/// Full or contained loading view that avoids blank screens and communicates what is loading.
class LoadingView extends StatelessWidget {
  final String? message;
  final bool isContained;

  const LoadingView({
    super.key,
    this.message = 'Loading...',
    this.isContained = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppTokens.s16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isContained) return content;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: content,
    );
  }
}
