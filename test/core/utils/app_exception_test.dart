import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/app_exception.dart';

void main() {
  group('userMessageFor', () {
    test('never leaks raw exception text for an unrecognised error', () {
      expect(userMessageFor(StateError('secret internals /users/abc')), 'Something went wrong. Please try again.');
      expect(userMessageFor(Exception('boom'), fallback: 'Could not save.'), 'Could not save.');
      expect(userMessageFor(null), 'Something went wrong. Please try again.');
    });

    test('maps connection problems to one clear message', () {
      const offline = 'No internet connection. Check your network and try again.';
      expect(userMessageFor(const SocketException('Failed host lookup')), offline);
      expect(userMessageFor(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), offline);
      expect(userMessageFor(FirebaseFunctionsException(message: 'x', code: 'unavailable')), offline);
      expect(userMessageFor(FirebaseFunctionsException(message: 'x', code: 'deadline-exceeded')), offline);
    });

    test('maps a timeout', () {
      expect(userMessageFor(TimeoutException('slow')), contains('timed out'));
    });

    test('maps Firestore permission and not-found errors without echoing the path', () {
      final denied = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions for /databases/(default)/documents/users/abc',
      );
      expect(userMessageFor(denied), "You don't have permission to do that.");
      expect(userMessageFor(denied), isNot(contains('/users/')));
      expect(userMessageFor(FirebaseException(plugin: 'p', code: 'not-found')), 'That no longer exists.');
    });

    test("passes through the message our own Cloud Functions wrote for the user", () {
      for (final code in ['failed-precondition', 'invalid-argument', 'permission-denied', 'not-found', 'resource-exhausted']) {
        expect(
          userMessageFor(FirebaseFunctionsException(message: 'Your cart is empty.', code: code)),
          'Your cart is empty.',
          reason: code,
        );
      }
    });

    test('does not show internal function errors', () {
      for (final code in ['internal', 'unknown', 'data-loss']) {
        expect(
          userMessageFor(FirebaseFunctionsException(message: 'INTERNAL', code: code), fallback: 'Try later.'),
          'Try later.',
          reason: code,
        );
      }
    });

    test('falls back when a function error has no message', () {
      expect(
        userMessageFor(FirebaseFunctionsException(message: '', code: 'failed-precondition'), fallback: 'Nope.'),
        'Nope.',
      );
    });

    test('asks the user to sign in again when the session is gone', () {
      expect(userMessageFor(FirebaseFunctionsException(message: 'x', code: 'unauthenticated')), contains('sign in'));
      expect(userMessageFor(FirebaseException(plugin: 'p', code: 'unauthenticated')), contains('sign in'));
    });
  });

  group('AppException', () {
    test('toString is the user message, so string interpolation can never print a class name', () {
      expect('${const AppException('Out of stock.')}', 'Out of stock.');
    });

    test('.from wraps an error with the action and a safe detail, keeping the code', () {
      final e = AppException.from(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied', message: 'raw /path'),
        action: 'add the product',
      );
      expect(e.message, "Couldn't add the product. You don't have permission to do that.");
      expect(e.code, 'permission-denied');
      expect(e.message, isNot(contains('raw')));
    });

    test('.from uses a generic detail for an unknown error', () {
      final e = AppException.from(StateError('internals'), action: 'save the banner');
      expect(e.message, "Couldn't save the banner. Please try again.");
      expect(e.code, isNull);
    });

    test('.from passes an AppException through untouched (a repository can throw its own text)', () {
      const own = AppException('Cannot delete a product with reserved stock.');
      expect(identical(AppException.from(own, action: 'delete the product'), own), isTrue);
    });
  });
}
