import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/domain/entities/rider_location.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';

class _Repo implements OrderRepository {
  final List<({String orderId, String status, RiderLocation? location})> advances = [];
  String? result;
  Object? throwsError;

  @override
  Future<String?> advanceOrderStatus(String orderId, String nextStatus, {RiderLocation? location}) async {
    if (throwsError != null) throw throwsError!;
    advances.add((orderId: orderId, status: nextStatus, location: location));
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('advanceStatus sends the next status and the rider location', () async {
    final repo = _Repo();
    final provider = OrderProvider(repository: repo);

    final error = await provider.advanceStatus(
      'o1',
      'picked_up',
      location: const RiderLocation(lat: 16.5, lng: 81.5, accuracyMeters: 9),
    );

    expect(error, isNull);
    expect(repo.advances.single.orderId, 'o1');
    expect(repo.advances.single.status, 'picked_up');
    expect(repo.advances.single.location?.accuracyMeters, 9);
    provider.dispose();
  });

  test('works without a location', () async {
    final repo = _Repo();
    final provider = OrderProvider(repository: repo);
    expect(await provider.advanceStatus('o1', 'picked_up'), isNull);
    expect(repo.advances.single.location, isNull);
    provider.dispose();
  });

  test("passes the server's message through for the rider", () async {
    final repo = _Repo()..result = 'This order was cancelled. Go back and check its status.';
    final provider = OrderProvider(repository: repo);
    expect(await provider.advanceStatus('o1', 'picked_up'),
        'This order was cancelled. Go back and check its status.');
    provider.dispose();
  });

  test('an unexpected exception becomes a safe message, never raw text', () async {
    final repo = _Repo()..throwsError = StateError('boom /orders/o1');
    final provider = OrderProvider(repository: repo);

    final error = await provider.advanceStatus('o1', 'picked_up');

    expect(error, isNotNull);
    expect(error, isNot(contains('boom')));
    expect(error, contains('latest status'));
    provider.dispose();
  });

  test('a function error carrying a user-facing message shows that message', () async {
    final repo = _Repo()
      ..throwsError = FirebaseFunctionsException(
          message: "The next step for this order is 'out_for_delivery'.", code: 'failed-precondition');
    final provider = OrderProvider(repository: repo);

    expect(await provider.advanceStatus('o1', 'picked_up'),
        "The next step for this order is 'out_for_delivery'.");
    provider.dispose();
  });
}
