import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/user_model.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<AuthResult> signInWithEmail(String email, String password);
  Future<AuthResult> registerWithEmail(String email, String password);
  Future<AuthResult> signInWithGoogle();
  Future<void> signOut();
  Future<bool> setupCustomerProfile(UserModel userModel);
  Future<bool> updateUserProfile(UserModel userModel);
  /// Queries Firestore across all 3 collections (admin → delivery → customer)
  /// and returns the first matching [UserModel] with its role field set.
  /// Returns `null` when the Firebase Auth user has no Firestore doc yet
  /// (i.e. a brand-new customer who needs profile setup).
  Future<UserModel?> discoverUserRole(String uid, String email);
  /// Fetches the profile for a *known* role — used by [reloadUserProfile] and
  /// address-management flows after the role has already been established.
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
