import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/user_model.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<AuthResult> signInWithEmail(String email, String password);
  Future<AuthResult> registerWithEmail(String email, String password);
  Future<AuthResult> signInWithGoogle();
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  });
  Future<AuthResult> signInWithPhoneCredential(PhoneAuthCredential credential);
  Future<void> signOut();
  Future<bool> authenticateBiometrically();
  Future<bool> setupCustomerProfile(UserModel userModel);
  Future<UserModel?> getUserProfile(String uid, String role);
  Future<void> saveDeliveryBoyUid(String docId, String uid);
}

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;

  AuthResult({
    required this.isSuccess,
    this.errorMessage,
    this.user,
  });
}
