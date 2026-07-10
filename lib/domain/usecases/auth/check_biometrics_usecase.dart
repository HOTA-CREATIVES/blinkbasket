import '../../repositories/auth_repository.dart';

class CheckBiometricsUseCase {
  final AuthRepository repository;
  CheckBiometricsUseCase(this.repository);

  Future<bool> call() => repository.authenticateBiometrically();
}
