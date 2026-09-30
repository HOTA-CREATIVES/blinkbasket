import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/contact_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('URLs', () {
    test('every spelling of a number dials the same +91 number', () {
      for (final raw in ['9876543210', '+91 98765 43210', '09876543210', '919876543210', '98765-43210']) {
        expect(ContactLauncher.callUri(raw).toString(), 'tel:+919876543210', reason: raw);
      }
    });

    test('WhatsApp uses wa.me with digits only (no +) and the country code', () {
      final uri = ContactLauncher.whatsAppUri('+91 98765 43210')!;
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/919876543210');
      expect(uri.hasQuery, isFalse);
    });

    test('the message is percent-encoded into ?text=', () {
      final uri = ContactLauncher.whatsAppUri('9876543210', message: "Hi Asha, I'm your rider — order #A1B2C3")!;
      expect(uri.queryParameters['text'], "Hi Asha, I'm your rider — order #A1B2C3");
      expect(uri.toString(), contains('text=Hi%20Asha'));
    });

    test('an unusable number gives no URL', () {
      for (final raw in [null, '', '12345', '5876543210', 'abc']) {
        expect(ContactLauncher.callUri(raw), isNull, reason: '$raw');
        expect(ContactLauncher.whatsAppUri(raw), isNull, reason: '$raw');
      }
    });
  });

  group('launching', () {
    test('call opens the dialler with the canonical number', () async {
      final launched = <Uri>[];
      final launcher = ContactLauncher(
        canLaunch: (_) async => true,
        launch: (uri, {mode = LaunchMode.platformDefault}) async {
          launched.add(uri);
          return true;
        },
      );

      expect(await launcher.call('98765 43210'), ContactResult.launched);
      expect(launched.single.toString(), 'tel:+919876543210');
    });

    test('WhatsApp opens in the external app, not inside this app', () async {
      final launched = <(Uri, LaunchMode)>[];
      final launcher = ContactLauncher(
        launch: (uri, {mode = LaunchMode.platformDefault}) async {
          launched.add((uri, mode));
          return true;
        },
      );

      expect(await launcher.whatsApp('9876543210', message: 'Hi'), ContactResult.launched);
      expect(launched.single.$1.toString(), 'https://wa.me/919876543210?text=Hi');
      expect(launched.single.$2, LaunchMode.externalApplication);
    });

    test('an invalid number never reaches the launcher', () async {
      var calls = 0;
      final launcher = ContactLauncher(
        canLaunch: (_) async {
          calls++;
          return true;
        },
        launch: (uri, {mode = LaunchMode.platformDefault}) async {
          calls++;
          return true;
        },
      );

      expect(await launcher.call('123'), ContactResult.invalidNumber);
      expect(await launcher.whatsApp(null), ContactResult.invalidNumber);
      expect(calls, 0);
    });

    test('a device that cannot dial reports unavailable', () async {
      final launcher = ContactLauncher(canLaunch: (_) async => false);
      expect(await launcher.call('9876543210'), ContactResult.unavailable);
    });

    test('a launcher that refuses or throws reports unavailable, never an exception', () async {
      final refuses = ContactLauncher(
        canLaunch: (_) async => true,
        launch: (uri, {mode = LaunchMode.platformDefault}) async => false,
      );
      final throws = ContactLauncher(
        canLaunch: (_) async => throw StateError('no handler'),
        launch: (uri, {mode = LaunchMode.platformDefault}) async => throw StateError('no handler'),
      );

      expect(await refuses.call('9876543210'), ContactResult.unavailable);
      expect(await refuses.whatsApp('9876543210'), ContactResult.unavailable);
      expect(await throws.call('9876543210'), ContactResult.unavailable);
      expect(await throws.whatsApp('9876543210'), ContactResult.unavailable);
    });
  });

  group('messageFor', () {
    test('is null on success and explains each failure in words', () {
      expect(ContactLauncher.messageFor(ContactResult.launched, what: 'WhatsApp'), isNull);
      expect(ContactLauncher.messageFor(ContactResult.invalidNumber, what: 'WhatsApp'), contains("isn't valid"));
      expect(ContactLauncher.messageFor(ContactResult.unavailable, what: 'WhatsApp'), contains("Couldn't open WhatsApp"));
    });
  });
}
