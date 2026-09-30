import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;

const _noConnection = 'No internet connection. Check your network and try again.';
const _timedOut = 'The request timed out. Check your connection and try again.';
const _generic = 'Something went wrong. Please try again.';

/// A failure whose [message] is written for the person using the app.
///
/// Repositories throw this instead of `Exception("... $e")`, which pasted raw
/// platform error text (class names, stack fragments, document paths) into
/// snackbars. Providers and screens show [message] as it is.
class AppException implements Exception {
  final String message;

  /// The underlying platform code (`permission-denied`, `unavailable`, ...) when
  /// there is one — for branching and logs, never for display.
  final String? code;

  const AppException(this.message, {this.code});

  /// Wraps any [error] from doing [action] ("add the product") into an
  /// exception with a safe message. An [AppException] is passed through
  /// untouched, so a repository can throw its own user-facing text.
  factory AppException.from(Object error, {required String action}) {
    if (error is AppException) return error;
    final detail = userMessageFor(error, fallback: 'Please try again.');
    return AppException("Couldn't $action. $detail", code: _codeOf(error));
  }

  @override
  String toString() => message;
}

String? _codeOf(Object error) {
  if (error is FirebaseFunctionsException) return error.code;
  if (error is FirebaseException) return error.code;
  return null;
}

/// The message to show a user for [error]: fixed wording for connection,
/// permission, timeout and not-found problems, the server's own text where the
/// server wrote it for users (Cloud Function precondition failures), and
/// [fallback] for anything unrecognised. Never the raw exception text.
String userMessageFor(Object? error, {String fallback = _generic}) {
  if (error == null) return fallback;
  if (error is AppException) return error.message;
  if (error is TimeoutException) return _timedOut;
  if (error is SocketException) return _noConnection;

  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please sign in again to continue.';
      case 'unavailable':
      case 'deadline-exceeded':
        return _noConnection;
      case 'internal':
      case 'unknown':
      case 'cancelled':
      case 'data-loss':
        return fallback;
      case 'not-found':
      case 'permission-denied':
      case 'already-exists':
      case 'failed-precondition':
      case 'invalid-argument':
      case 'resource-exhausted':
      case 'out-of-range':
        // These are raised by our own functions with text written for users.
        final text = (error.message ?? '').trim();
        return text.isEmpty ? fallback : text;
      default:
        return fallback;
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return "You don't have permission to do that.";
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return _noConnection;
      case 'not-found':
        return 'That no longer exists.';
      case 'aborted':
        return 'That changed while you were working. Please try again.';
      case 'unauthenticated':
        return 'Please sign in again to continue.';
      default:
        return fallback;
    }
  }

  return fallback;
}
