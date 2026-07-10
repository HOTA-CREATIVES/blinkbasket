import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository repository;
  VerifyOtpUseCase(this.repository);

  Future<AuthResult> call(PhoneAuthCredential credential) => repository.signInWithPhoneCredential(credential);
}
