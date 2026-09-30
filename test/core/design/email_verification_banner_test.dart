import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/design/widgets/email_verification_banner.dart';
import 'package:hypermart/core/models/user_model.dart';
import 'package:hypermart/core/providers/auth_provider.dart';
import 'package:hypermart/domain/repositories/auth_repository.dart';
import 'package:provider/provider.dart';

class _FakeAuthRepository implements AuthRepository {
  bool verified;
  bool verifiedAfterRefresh;
  String? sendError;
  int sends = 0;
  int refreshes = 0;

  _FakeAuthRepository({
    this.verified = false,
    this.verifiedAfterRefresh = false,
    this.sendError,
  });

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  User? get currentUser => null;

  @override
  bool get isEmailVerified => verified;

  @override
  Future<String?> sendEmailVerification() async {
    sends++;
    return sendError;
  }

  @override
  Future<bool> refreshEmailVerification() async {
    refreshes++;
    verified = verifiedAfterRefresh;
    return verified;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _user() => UserModel(
      uid: 'u1',
      name: 'Asha',
      email: 'asha@example.com',
      phone: '9876543210',
      role: 'customer',
      village: 'Bhimavaram',
      createdAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester, _FakeAuthRepository repo) async {
  // The tree owns (and disposes) the provider, which also cancels its
  // periodic token-refresh timer before the test framework checks for leaks.
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(repository: repo)..updateCurrentUserModel(_user()),
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: EmailVerificationBanner())),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing for a verified account', (tester) async {
    await _pump(tester, _FakeAuthRepository(verified: true));
    expect(find.textContaining('Verify your email'), findsNothing);
    expect(find.text('Resend link'), findsNothing);
  });

  testWidgets('tells an unverified customer why they cannot order and where the link went',
      (tester) async {
    await _pump(tester, _FakeAuthRepository());
    expect(find.textContaining('Verify your email to place orders'), findsOneWidget);
    expect(find.textContaining('asha@example.com'), findsOneWidget);
  });

  testWidgets('Resend link sends one email and confirms it', (tester) async {
    final repo = _FakeAuthRepository();
    await _pump(tester, repo);

    await tester.tap(find.text('Resend link'));
    await tester.pumpAndSettle();

    expect(repo.sends, 1);
    expect(find.text('Verification email sent. Check your inbox.'), findsOneWidget);
  });

  testWidgets('Resend link shows the failure message instead of claiming success',
      (tester) async {
    final repo = _FakeAuthRepository(sendError: 'Too many requests. Wait a few minutes and try again.');
    await _pump(tester, repo);

    await tester.tap(find.text('Resend link'));
    await tester.pumpAndSettle();

    expect(find.text('Too many requests. Wait a few minutes and try again.'), findsOneWidget);
    expect(find.text('Verification email sent. Check your inbox.'), findsNothing);
  });

  testWidgets("I've verified re-checks the account and hides the banner once verified",
      (tester) async {
    final repo = _FakeAuthRepository(verifiedAfterRefresh: true);
    await _pump(tester, repo);

    await tester.tap(find.text("I've verified"));
    await tester.pumpAndSettle();

    expect(repo.refreshes, 1);
    expect(find.textContaining('Verify your email'), findsNothing);
  });

  testWidgets("I've verified explains when the email is still unverified", (tester) async {
    final repo = _FakeAuthRepository();
    await _pump(tester, repo);

    await tester.tap(find.text("I've verified"));
    await tester.pumpAndSettle();

    expect(find.textContaining("isn't verified yet"), findsOneWidget);
    expect(find.textContaining('Verify your email to place orders'), findsOneWidget);
  });
}
