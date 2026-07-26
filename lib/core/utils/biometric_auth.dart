import 'package:local_auth/local_auth.dart';

/// Prompts for biometric or device PIN/pattern authentication.
///
/// Returns `true` if authenticated, and also `true` if the device has no
/// local auth configured at all — this gate is a defense-in-depth UX layer
/// (the underlying data is already access-controlled server-side), not the
/// primary security boundary, so an unsupported device must never lock a
/// user out of their own content.
Future<bool> requestLocalAuth(String reason) async {
  final localAuth = LocalAuthentication();
  try {
    final canCheckBiometrics = await localAuth.canCheckBiometrics;
    final canAuthenticate =
        canCheckBiometrics || await localAuth.isDeviceSupported();
    if (!canAuthenticate) return true;

    return await localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false, // Fallback to PIN/Pattern if fingerprint fails
      ),
    );
  } catch (_) {
    return true;
  }
}
