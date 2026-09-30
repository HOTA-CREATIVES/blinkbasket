import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/app_exception.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // GoogleSignIn is only used on Android/iOS. On web, google_sign_in_web
  // requires a configured OAuth clientId in index.html — skip it entirely
  // to avoid a DartError assertion crash at startup.
  GoogleSignIn? get _googleSignIn => kIsWeb ? null : GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(isSuccess: true, user: credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: _getReadableFirebaseAuthError(e.code),
      );
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: userMessageFor(e));
    }
  }

  /// Minimal customer stub shared by [registerCustomer] (fresh email signup)
  /// and [discoverUserRole] (brand-new Auth user with no Firestore doc yet,
  /// e.g. a Google sign-in). Idempotent (merge: true) — safe even if some
  /// other listener raced us.
  Map<String, dynamic> _newCustomerStub({
    required String uid,
    required String email,
    String? name,
    String? phone,
    String? avatarUrl,
  }) {
    final now = DateTime.now();
    return {
      'uid': uid,
      'name': name ?? '',
      'email': email.trim().toLowerCase(),
      'phone': phone ?? '',
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      'role': 'customer',
      'isActive': true,
      'onboardingCompleted': false,
      'onboardingStep': 1,
      'village': '',
      'mandal': '',
      'district': '',
      'deliveryAvailable': true,
      'deliveryZoneId': '',
      'totalOrders': 0,
      'totalSpent': 0.0,
      'firstOrderCompleted': false,
      'favoriteProductIds': <String>[],
      'fcmTokens': <String>[],
      'addresses': <Map<String, dynamic>>[],
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  @override
  Future<AuthResult> registerCustomer(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return AuthResult(isSuccess: false, errorMessage: "Failed to create account.");
      }

      // Best effort: the user can resend from the home screen banner.
      unawaited(user.sendEmailVerification().catchError((Object e) {
        debugPrint('registerCustomer: verification email not sent: $e');
      }));

      // Seed the matching Firestore customer stub immediately so a user
      // who closes the app mid-onboarding doesn't leave an orphan Auth
      // account.
      final initialDoc = _newCustomerStub(
        uid: user.uid,
        email: email,
        name: user.displayName,
        phone: user.phoneNumber,
      );
      try {
        await _firestore.collection('users').doc(user.uid).set(
              initialDoc,
              SetOptions(merge: true),
            );
      } catch (e) {
        debugPrint('registerCustomer: Firestore stub write failed (will retry on profile setup): $e');
      }

      return AuthResult(isSuccess: true, user: user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: _getReadableFirebaseAuthError(e.code),
      );
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: userMessageFor(e));
    }
  }

  @override
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  @override
  Future<String?> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return 'Sign in again to verify your email.';
    try {
      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('sendEmailVerification failed: ${e.code}');
      if (e.code == 'too-many-requests') {
        return 'Too many requests. Wait a few minutes and try again.';
      }
      if (e.code == 'network-request-failed') {
        return 'No internet connection. Check your network and try again.';
      }
      return "Couldn't send the verification email. Please try again.";
    } catch (e) {
      debugPrint('sendEmailVerification unexpected: $e');
      return "Couldn't send the verification email. Please try again.";
    }
  }

  @override
  Future<bool> refreshEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.reload();
      // The Cloud Functions read email_verified from the ID token, which only
      // updates on refresh.
      await _auth.currentUser?.getIdToken(true);
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('refreshEmailVerification failed: $e');
      return _auth.currentUser?.emailVerified ?? false;
    }
  }

  @override
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('sendPasswordReset failed: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('sendPasswordReset unexpected: $e');
      return false;
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    if (kIsWeb) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Google Sign-In is not available on web in this build.',
      );
    }
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        return AuthResult(isSuccess: false, errorMessage: "Google Sign-In was cancelled.");
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return AuthResult(isSuccess: true, user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: _getReadableFirebaseAuthError(e.code),
      );
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: userMessageFor(e));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn?.signOut();
  }

  @override
  Future<UserModel?> discoverUserRole(String uid, String email) async {
    final normalizedEmail = email.toLowerCase().trim();

    // Priority 1: Admin
    try {
      final adminDoc = await _firestore.collection('admins').doc(uid).get();
      if (adminDoc.exists && adminDoc.data() != null) {
        return UserModel.fromMap({...adminDoc.data()!, 'role': 'admin'}, adminDoc.id);
      }
    } catch (e) {
      debugPrint('discoverUserRole admin by UID check note: $e');
    }

    // Priority 2: Delivery partner — check by UID first (matches security rule docId == request.auth.uid),
    // then fall back to email query.
    try {
      final deliveryDoc = await _firestore.collection('deliveryBoys').doc(uid).get();
      if (deliveryDoc.exists && deliveryDoc.data() != null) {
        return UserModel.fromMap({...deliveryDoc.data()!, 'role': 'delivery'}, deliveryDoc.id);
      }
    } catch (e) {
      debugPrint('discoverUserRole delivery by UID check note: $e');
    }

    if (normalizedEmail.isNotEmpty) {
      try {
        final deliveryQuery = await _firestore
            .collection('deliveryBoys')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (deliveryQuery.docs.isNotEmpty) {
          final doc = deliveryQuery.docs.first;
          return UserModel.fromMap({...doc.data(), 'role': 'delivery'}, doc.id);
        }
      } catch (e) {
        debugPrint('discoverUserRole delivery check note: $e');
      }
    }

    // Priority 3: Customer — by UID only. New email registrations seed
    // their stub in `registerCustomer` before this runs; legacy email-only
    // Google sign-ins fall through to the empty-customer-doc branch below.
    final firebaseUser = currentUser;
    final photoURL = firebaseUser?.photoURL;

    try {
      final customerDoc = await _firestore.collection('users').doc(uid).get();
      if (customerDoc.exists && customerDoc.data() != null) {
        final data = Map<String, dynamic>.from(customerDoc.data()!);
        if (photoURL != null && photoURL.isNotEmpty) {
          final existingAvatar = data['avatarUrl'] as String?;
          if (existingAvatar == null || existingAvatar.isEmpty) {
            data['avatarUrl'] = photoURL;
            try {
              await _firestore.collection('users').doc(uid).update({'avatarUrl': photoURL});
            } catch (e) {
              debugPrint('Updating customer avatarUrl note: $e');
            }
          }
        }
        return UserModel.fromMap(data, customerDoc.id);
      }
    } catch (e) {
      debugPrint('discoverUserRole customer check note: $e');
    }

    // Brand-new Firebase Auth user with no Firestore doc anywhere — seed
    // a minimal customer stub so role discovery stays consistent across
    // cold-start, fresh-signin and Google-rebind paths.
    final user = currentUser;
    final initialDoc = _newCustomerStub(
      uid: uid,
      email: normalizedEmail,
      name: user?.displayName,
      phone: user?.phoneNumber,
      avatarUrl: user?.photoURL,
    );
    try {
      await _firestore.collection('users').doc(uid).set(initialDoc, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Initial customer doc creation note: $e');
    }

    return null;
  }

  @override
  Future<bool> setupCustomerProfile(UserModel userModel) async {
    try {
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap(), SetOptions(merge: true));
      return true;
    } catch (e, stack) {
      debugPrint("Firestore setup profile error: $e\n$stack");
      return false;
    }
  }

  @override
  Future<bool> updateUserProfile(UserModel userModel) async {
    try {
      if (userModel.role == 'delivery') {
        final String docPath = userModel.docId ?? userModel.uid;
        final updates = {
          'name': userModel.name,
          'phone': userModel.phone,
          'village': userModel.village,
          if (userModel.avatarUrl != null) 'avatarUrl': userModel.avatarUrl,
          if (userModel.vehicleDetails != null) 'vehicleDetails': userModel.vehicleDetails,
          if (userModel.vehicleNo != null) 'vehicleNo': userModel.vehicleNo,
          if (userModel.licenseNo != null) 'licenseNo': userModel.licenseNo,
        };
        await _firestore.collection('deliveryBoys').doc(docPath).set(updates, SetOptions(merge: true));
        return true;
      }

      if (userModel.role == 'admin') {
        debugPrint("updateUserProfile: admin profile edits are not supported client-side.");
        return false;
      }

      await _firestore.collection('users').doc(userModel.uid).set(userModel.toProfileUpdateMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint("Firestore update profile error: $e");
      return false;
    }
  }

  @override
  Future<UserModel?> getUserProfile(String uid, String role) async {
    try {
      if (role == 'customer') {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data()!, doc.id);
        }
      } else if (role == 'delivery') {
        // Try direct lookup by UID first
        final directDoc = await _firestore.collection('deliveryBoys').doc(uid).get();
        if (directDoc.exists) {
          return UserModel.fromMap({...directDoc.data()!, 'role': 'delivery'}, directDoc.id);
        }
        // Fallback to email query
        final user = currentUser;
        final email = user?.email;
        if (email != null) {
          final query = await _firestore
              .collection('deliveryBoys')
              .where('email', isEqualTo: email.toLowerCase().trim())
              .get();
          if (query.docs.isNotEmpty) {
            final doc = query.docs.first;
            return UserModel.fromMap({...doc.data(), 'role': 'delivery'}, doc.id);
          }
        }
      } else if (role == 'admin') {
        final doc = await _firestore.collection('admins').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap({...doc.data()!, 'role': 'admin'}, doc.id);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Same as [getUserProfile] but goes via the canonical UID-keyed doc
  /// when it exists. Used by the auth listener on token refresh so an
  /// admin can de/activate a rider and the rider's app reflects it
  /// without forcing them to log out.
  @override
  Future<UserModel?> refreshUserProfile(String uid, String role) async {
    try {
      if (role == 'delivery') {
        final doc = await _firestore.collection('deliveryBoys').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap({...doc.data()!, 'role': 'delivery'}, doc.id);
        }
        return await getUserProfile(uid, role);
      }
      if (role == 'customer') {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data()!, doc.id);
        }
      } else if (role == 'admin') {
        final doc = await _firestore.collection('admins').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap({...doc.data()!, 'role': 'admin'}, doc.id);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> deleteAccount() async {
    try {
      final callable = _functions.httpsCallable('deleteAccount');
      await callable.call();
      await signOut();
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Error during deleteAccount: ${e.code} ${e.message}');
      // The server's message is written for the customer, e.g. "You have an
      // order in progress. Delete your account after it is delivered…".
      return e.message ?? 'Failed to delete account. Please try again later.';
    } catch (e) {
      debugPrint('Error during deleteAccount: $e');
      return 'Failed to delete account. Check your connection and try again.';
    }
  }

  String _getReadableFirebaseAuthError(String code) {
    debugPrint('FirebaseAuthException code: $code');
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      // One message for "no such user", "wrong password" and a bad credential:
      // separate messages let anyone probe which emails are registered.
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'operation-not-allowed':
        return 'This login method is not enabled.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password.';
      case 'invalid-verification-code':
        return 'The entered OTP code is incorrect. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification request. Please request a new OTP.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      default:
        // The code is already logged above; users don't need it.
        return 'Something went wrong. Please try again.';
    }
  }
}
