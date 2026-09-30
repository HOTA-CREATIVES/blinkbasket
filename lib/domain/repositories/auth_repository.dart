import 'package:firebase_auth/firebase_auth.dart';
import '../../core/models/user_model.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<AuthResult> signInWithEmail(String email, String password);
  /// Creates the Firebase Auth account AND a matching Firestore customer
  /// stub in one shot, so a user that closes the app mid-onboarding doesn't
  /// leave an orphan Auth account. Returns the fresh [User] on success.
  Future<AuthResult> registerCustomer(String email, String password);
  Future<AuthResult> signInWithGoogle();
  Future<bool> sendPasswordReset(String email);
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
  /// Re-resolves the live role + isActive state from Firestore. Used by
  /// [reloadUserProfile] and by the auth listener when a token refreshes,
  /// so an admin deactivating a rider mid-session doesn't leave a stale
  /// privileged [UserModel] in the provider.
  Future<UserModel?> refreshUserProfile(String uid, String role);
  /// Deletes the signed-in account. Returns null on success, or a message
  /// written for the user explaining why it couldn't be done (for example an
  /// order is still in progress).
  Future<String?> deleteAccount();
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
