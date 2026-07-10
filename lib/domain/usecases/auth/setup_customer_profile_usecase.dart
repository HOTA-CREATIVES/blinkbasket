import '../../../core/models/user_model.dart';
import '../../repositories/auth_repository.dart';

class SetupCustomerProfileUseCase {
  final AuthRepository repository;
  SetupCustomerProfileUseCase(this.repository);

  Future<bool> call(UserModel userModel) => repository.setupCustomerProfile(userModel);
}
