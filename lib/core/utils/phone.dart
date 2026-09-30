/// Canonical 10-digit Indian mobile number from what a user may type
/// ("9876543210", "+91 98765 43210", "09876543210"), or null when it isn't a
/// valid one. Mirrors `normalizeIndianMobile` in the Cloud Functions, which
/// refuses to dispatch an order without a callable number.
String? normalizeIndianMobile(String? raw) {
  final compact = (raw ?? '').replaceAll(RegExp(r'[\s-]'), '');
  final match = RegExp(r'^(?:\+?91|0)?([6-9]\d{9})$').firstMatch(compact);
  return match?.group(1);
}

/// Form validator for a mobile-number field.
String? validateIndianMobile(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your mobile number';
  if (normalizeIndianMobile(value) == null) {
    return 'Enter a valid 10-digit mobile number';
  }
  return null;
}
