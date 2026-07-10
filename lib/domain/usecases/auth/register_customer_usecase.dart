import '../../repositories/auth_repository.dart';

class RegisterCustomerUseCase {
  final AuthRepository repository;
  RegisterCustomerUseCase(this.repository);

  Future<AuthResult> call(String email, String password) => repository.registerWithEmail(email, password);
}
