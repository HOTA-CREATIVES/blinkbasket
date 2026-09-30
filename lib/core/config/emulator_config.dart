import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Configuration helper for Firebase Local Emulator Suite.
class EmulatorConfig {
  /// Toggle via `--dart-define=USE_FIREBASE_EMULATOR=true`
  static const bool useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  /// Custom host override via `--dart-define=EMULATOR_HOST=192.168.1.X`
  static const String customHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '',
  );

  /// Configures Firebase services to use local emulators if enabled.
  static Future<void> configureEmulators() async {
    if (!useEmulator) {
      debugPrint('ℹ️ Firebase Emulators: Disabled (using production/staging Firebase)');
      return;
    }

    final String host = _getEmulatorHost();
    debugPrint('🚀 Firebase Emulators: Enabling on host $host');

    try {
      // 1. Auth Emulator
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);

      // 2. Firestore Emulator - Configure persistence settings before emulator hook
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
          sslEnabled: false,
        );
      } catch (e) {
        debugPrint('ℹ️ Firestore settings already initialized: $e');
      }

      FirebaseFirestore.instance.useFirestoreEmulator(
        host,
        8090,
        sslEnabled: false,
      );

      // 3. Functions Emulator (both default and asia-south1 regional instances)
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      FirebaseFunctions.instanceFor(region: 'asia-south1')
          .useFunctionsEmulator(host, 5001);

      debugPrint('✅ Firebase Emulators initialized successfully:');
      debugPrint('   - Auth: http://$host:9099');
      debugPrint('   - Firestore: http://$host:8090');
      debugPrint('   - Functions: http://$host:5001');
      debugPrint('   - Dashboard UI: http://localhost:4000');
    } catch (e) {
      debugPrint('⚠️ Error initializing Firebase Emulators: $e');
    }
  }

  static String _getEmulatorHost() {
    if (customHost.isNotEmpty) {
      return customHost;
    }
    if (kIsWeb) {
      return 'localhost';
    }
    if (Platform.isAndroid) {
      return '10.0.2.2'; // Standard loopback for Android Virtual Device
    }
    return '127.0.0.1';
  }
}
