import 'package:url_launcher/url_launcher.dart';
import 'phone.dart';

/// Whether opening the phone dialler or WhatsApp worked.
enum ContactResult { launched, invalidNumber, unavailable }

/// Calls and WhatsApp chats for the customer ↔ rider hand-off. Numbers are
/// normalised to the canonical 10 digits first (`+91` is added), so a stored
/// `+91 98765 43210`, `09876543210` or `9876543210` all dial the same way.
class ContactLauncher {
  /// The launching functions are injectable so URL building and failure
  /// handling can be tested without a device.
  ContactLauncher({
    Future<bool> Function(Uri uri)? canLaunch,
    Future<bool> Function(Uri uri, {LaunchMode mode})? launch,
  })  : _canLaunch = canLaunch ?? canLaunchUrl,
        _launch = launch ?? ((uri, {mode = LaunchMode.platformDefault}) => launchUrl(uri, mode: mode));

  final Future<bool> Function(Uri uri) _canLaunch;
  final Future<bool> Function(Uri uri, {LaunchMode mode}) _launch;

  /// `tel:+91XXXXXXXXXX`, or null for a number that can't be dialled.
  static Uri? callUri(String? phone) {
    final number = normalizeIndianMobile(phone);
    return number == null ? null : Uri(scheme: 'tel', path: '+91$number');
  }

  /// `https://wa.me/91XXXXXXXXXX?text=…` (wa.me wants digits only, no `+`), or
  /// null for a number that can't be messaged.
  static Uri? whatsAppUri(String? phone, {String? message}) {
    final number = normalizeIndianMobile(phone);
    if (number == null) return null;
    final base = 'https://wa.me/91$number';
    // Percent-encoded (%20), not form-encoded (+): that is what wa.me documents.
    return Uri.parse((message == null || message.isEmpty)
        ? base
        : '$base?text=${Uri.encodeComponent(message)}');
  }

  Future<ContactResult> call(String? phone) async {
    final uri = callUri(phone);
    if (uri == null) return ContactResult.invalidNumber;
    try {
      if (!await _canLaunch(uri)) return ContactResult.unavailable;
      return await _launch(uri) ? ContactResult.launched : ContactResult.unavailable;
    } catch (_) {
      return ContactResult.unavailable;
    }
  }

  Future<ContactResult> whatsApp(String? phone, {String? message}) async {
    final uri = whatsAppUri(phone, message: message);
    if (uri == null) return ContactResult.invalidNumber;
    try {
      // External application: hands the chat to WhatsApp itself rather than
      // rendering wa.me inside the app.
      return await _launch(uri, mode: LaunchMode.externalApplication)
          ? ContactResult.launched
          : ContactResult.unavailable;
    } catch (_) {
      return ContactResult.unavailable;
    }
  }

  /// User-facing text for a failed [result], or null when it worked.
  static String? messageFor(ContactResult result, {required String what}) {
    switch (result) {
      case ContactResult.launched:
        return null;
      case ContactResult.invalidNumber:
        return "This phone number isn't valid, so we can't open $what.";
      case ContactResult.unavailable:
        return "Couldn't open $what on this device.";
    }
  }
}
