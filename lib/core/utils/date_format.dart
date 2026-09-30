const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `30 Sep 2026` — one unambiguous date format for the whole app (no locale
/// dependency, and never the d/m vs m/d guessing game).
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// `30 Sep 2026, 4:05 PM`.
String formatDateTime(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${formatDate(date)}, $hour12:$minute $period';
}

/// `4:05 PM`.
String formatTime(DateTime date) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
