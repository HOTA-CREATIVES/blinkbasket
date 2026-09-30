import 'package:flutter/material.dart';
import '../app_tokens.dart';

/// Read-only page for admin-authored legal text (privacy policy, terms).
///
/// Deliberately tiny formatting so an admin can write it in a text box:
/// a blank line separates paragraphs, and a line starting with `#` is a
/// heading. Text is selectable so users can copy it.
class LegalDocumentView extends StatelessWidget {
  final String title;
  final String body;

  const LegalDocumentView({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocks = body
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.s20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTokens.s20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.rXl),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final block in blocks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.s16),
                    child: block.startsWith('#')
                        ? Text(
                            block.replaceFirst(RegExp(r'^#+\s*'), ''),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          )
                        : Text(block, style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurface)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
