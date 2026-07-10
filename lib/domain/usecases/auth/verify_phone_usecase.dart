import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';

class VerifyPhoneUseCase {
  final AuthRepository repository;
  VerifyPhoneUseCase(this.repository);

  Future<void> call({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) =>
      repository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      );
}
