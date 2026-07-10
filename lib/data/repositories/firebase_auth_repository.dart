import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/models/user_model.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      return AuthResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<AuthResult> registerWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
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
      return AuthResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
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
      return AuthResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  Future<AuthResult> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return AuthResult(isSuccess: true, user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: _getReadableFirebaseAuthError(e.code),
      );
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  @override
  Future<bool> authenticateBiometrically() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canAuthenticateWithBiometrics && !isDeviceSupported) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the Admin Dashboard',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setupCustomerProfile(UserModel userModel) async {
    try {
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());
      return true;
    } catch (e) {
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
        final phone = currentUser?.phoneNumber;
        if (phone != null) {
          final query = await _firestore
              .collection('admins')
              .where('phone', isEqualTo: phone)
              .get();
          if (query.docs.isNotEmpty) {
            final doc = query.docs.first;
            return UserModel.fromMap({...doc.data(), 'role': 'admin'}, doc.id);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveDeliveryBoyUid(String docId, String uid) async {
    await _firestore.collection('deliveryBoys').doc(docId).update({
      'uid': uid,
    });
  }

  String _getReadableFirebaseAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found for this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'operation-not-allowed':
        return 'This login method is not enabled.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check and try again.';
      case 'invalid-verification-code':
        return 'The entered OTP code is incorrect. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification request. Please request a new OTP.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
