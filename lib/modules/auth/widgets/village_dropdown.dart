import 'package:flutter/material.dart';
import '../../../core/data/villages.dart';

class VillageDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Live zone names from Firestore. When null, falls back to the static
  /// [Villages.names] list so the widget always has something to show.
  final List<String>? zoneNames;

  const VillageDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.zoneNames,
  });

  List<String> get _effectiveNames => (zoneNames != null && zoneNames!.isNotEmpty)
      ? zoneNames!
      : Villages.names;

  @override
  Widget build(BuildContext context) {
    // Ensure current value is in the list; if not, reset to null to avoid
    // an invalid DropdownButtonFormField value assertion.
    final effectiveValue = _effectiveNames.contains(value) ? value : null;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          hint: Text(
            'Select your Village / Zone',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
          ),
          icon: Icon(Icons.arrow_drop_down_circle_outlined, color: scheme.primary),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          items: _effectiveNames.map((String name) {
            return DropdownMenuItem<String>(
              value: name,
              child: Text(
                name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a village / zone';
            }
            return null;
          },
        ),
      ),
    );
  }
}

