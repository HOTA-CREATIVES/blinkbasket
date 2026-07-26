import 'package:flutter/foundation.dart';

class BackendConfig {
  /// Toggle this to [true] to route Cloud Function calls to the local Node.js Express backend.
  /// Must be [false] in production builds — the local Node backend only exists for dev testing.
  static const bool useNodeBackend = false;

  /// URL of the Node.js Express backend.
  /// - Use 'http://10.0.2.2:3000' for the Android emulator.
  /// - Use 'http://localhost:3000' for web/iOS emulator/windows.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // Set to Android emulator loopback if running on Android, otherwise localhost
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }
}
