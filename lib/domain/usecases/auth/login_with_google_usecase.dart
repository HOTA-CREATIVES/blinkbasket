import '../../repositories/auth_repository.dart';

class LoginWithGoogleUseCase {
  final AuthRepository repository;
  LoginWithGoogleUseCase(this.repository);

  Future<AuthResult> call() => repository.signInWithGoogle();
}
