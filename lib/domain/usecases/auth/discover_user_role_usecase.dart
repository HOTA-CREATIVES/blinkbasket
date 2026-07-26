import '../../../core/models/user_model.dart';
import '../../repositories/auth_repository.dart';

/// Queries Firestore across admin → delivery → customer collections to
/// automatically resolve the role for a signed-in Firebase Auth user.
/// Returns `null` when no existing Firestore profile is found (new customer).
class DiscoverUserRoleUseCase {
  final AuthRepository _repository;

  DiscoverUserRoleUseCase(this._repository);

  Future<UserModel?> call(String uid, String email) =>
      _repository.discoverUserRole(uid, email);
}
