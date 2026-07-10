import '../../repositories/auth_repository.dart';

class LoginWithEmailUseCase {
  final AuthRepository repository;
  LoginWithEmailUseCase(this.repository);

  Future<AuthResult> call(String email, String password) => repository.signInWithEmail(email, password);
}
