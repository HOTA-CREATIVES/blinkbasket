import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth/login_with_email_usecase.dart';
import '../../domain/usecases/auth/login_with_google_usecase.dart';
import '../../domain/usecases/auth/register_customer_usecase.dart';
import '../../domain/usecases/auth/verify_phone_usecase.dart';
import '../../domain/usecases/auth/verify_otp_usecase.dart';
import '../../domain/usecases/auth/check_biometrics_usecase.dart';
import '../../domain/usecases/auth/setup_customer_profile_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../data/repositories/firebase_auth_repository.dart';

enum AuthStatus {
  uninitialized,
  authenticating,
  authenticated,
  unauthenticated,
  needsProfileSetup,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = FirebaseAuthRepository();

  late final LoginWithEmailUseCase _loginWithEmailUseCase;
  late final LoginWithGoogleUseCase _loginWithGoogleUseCase;
  late final RegisterCustomerUseCase _registerCustomerUseCase;
  late final VerifyPhoneUseCase _verifyPhoneUseCase;
  late final VerifyOtpUseCase _verifyOtpUseCase;
  late final CheckBiometricsUseCase _checkBiometricsUseCase;
  late final SetupCustomerProfileUseCase _setupCustomerProfileUseCase;
  late final LogoutUseCase _logoutUseCase;

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedRole;

  AuthProvider() {
    _loginWithEmailUseCase = LoginWithEmailUseCase(_authRepository);
    _loginWithGoogleUseCase = LoginWithGoogleUseCase(_authRepository);
    _registerCustomerUseCase = RegisterCustomerUseCase(_authRepository);
    _verifyPhoneUseCase = VerifyPhoneUseCase(_authRepository);
    _verifyOtpUseCase = VerifyOtpUseCase(_authRepository);
    _checkBiometricsUseCase = CheckBiometricsUseCase(_authRepository);
    _setupCustomerProfileUseCase = SetupCustomerProfileUseCase(_authRepository);
    _logoutUseCase = LogoutUseCase(_authRepository);

    _authRepository.authStateChanges.listen(_onAuthStateChanged);
    _loadSelectedRole();
  }

  // Getters
  AuthStatus get status => _status;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedRole => _selectedRole;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> _loadSelectedRole() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedRole = prefs.getString('selected_role');
    notifyListeners();
  }

  Future<void> setSelectedRole(String? role) async {
    _selectedRole = role;
    final prefs = await SharedPreferences.getInstance();
    if (role == null) {
      await prefs.remove('selected_role');
    } else {
      await prefs.setString('selected_role', role);
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> registerCustomerWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _registerCustomerUseCase(email, password);

    if (!result.isSuccess) {
      _errorMessage = result.errorMessage;
      _setLoading(false);
      return false;
    }

    await setSelectedRole('customer');
    _status = AuthStatus.needsProfileSetup;
    _setLoading(false);
    return true;
  }

  Future<bool> loginWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    await setSelectedRole(role);

    final result = await _loginWithEmailUseCase(email, password);

    if (!result.isSuccess) {
      _errorMessage = result.errorMessage;
      _setLoading(false);
      return false;
    }

    final user = result.user;
    if (user != null) {
      return await _verifyUserRoleAndInitialize(user, role);
    }

    _setLoading(false);
    return false;
  }

  Future<bool> loginWithGoogle({required String role}) async {
    _setLoading(true);
    _errorMessage = null;
    await setSelectedRole(role);

    final result = await _loginWithGoogleUseCase();

    if (!result.isSuccess) {
      _errorMessage = result.errorMessage;
      _setLoading(false);
      return false;
    }

    final user = result.user;
    if (user != null) {
      return await _verifyUserRoleAndInitialize(user, role);
    }

    _setLoading(false);
    return false;
  }

  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String, int?) codeSent,
    required Function(String) verificationFailed,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    await setSelectedRole('admin');

    await _verifyPhoneUseCase(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        final result = await _verifyOtpUseCase(credential);
        if (result.isSuccess && result.user != null) {
          await _verifyUserRoleAndInitialize(result.user!, 'admin');
        } else {
          _errorMessage = result.errorMessage;
          _setLoading(false);
          verificationFailed(result.errorMessage ?? 'Verification failed');
        }
      },
      verificationFailed: (exception) {
        _errorMessage = exception.message ?? 'Phone verification failed';
        _setLoading(false);
        verificationFailed(_errorMessage!);
      },
      codeSent: (verificationId, resendToken) {
        _setLoading(false);
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _setLoading(false);
      },
    );
  }

  Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final result = await _verifyOtpUseCase(credential);
    if (!result.isSuccess) {
      _errorMessage = result.errorMessage;
      _setLoading(false);
      return false;
    }

    final user = result.user;
    if (user != null) {
      return await _verifyUserRoleAndInitialize(user, 'admin');
    }

    _setLoading(false);
    return false;
  }

  Future<bool> setupCustomerProfile({
    required String name,
    required String village,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _errorMessage = "No authenticated user session found.";
      return false;
    }

    _setLoading(true);
    final userModel = UserModel(
      uid: user.uid,
      name: name,
      email: user.email ?? '',
      phone: user.phoneNumber ?? '',
      village: village,
      role: 'customer',
      isActive: true,
      createdAt: DateTime.now(),
    );

    final success = await _setupCustomerProfileUseCase(userModel);
    if (success) {
      _currentUserModel = userModel;
      _status = AuthStatus.authenticated;
      _setLoading(false);
      notifyListeners();
      return true;
    } else {
      _errorMessage = "Failed to save profile.";
      _setLoading(false);
      return false;
    }
  }

  Future<bool> checkBiometrics() async {
    return await _checkBiometricsUseCase();
  }

  Future<void> logout() async {
    _setLoading(true);
    await _logoutUseCase();
    _currentUserModel = null;
    await setSelectedRole(null);
    _status = AuthStatus.unauthenticated;
    _setLoading(false);
  }

  Future<bool> _verifyUserRoleAndInitialize(User user, String role) async {
    try {
      final model = await _authRepository.getUserProfile(user.uid, role);
      if (role == 'customer') {
        if (model == null) {
          _status = AuthStatus.needsProfileSetup;
          _setLoading(false);
          notifyListeners();
          return true;
        }

        if (!model.isActive) {
          await logout();
          _errorMessage = "Your account is deactivated. Contact support.";
          _setLoading(false);
          return false;
        }

        _currentUserModel = model;
        _status = AuthStatus.authenticated;
        _setLoading(false);
        notifyListeners();
        return true;
      } 
      
      else if (role == 'delivery') {
        if (model == null) {
          await logout();
          _errorMessage = "Not registered as delivery partner. Contact Admin.";
          _setLoading(false);
          return false;
        }

        if (!model.isActive) {
          await logout();
          _errorMessage = "Delivery partner account is inactive. Contact Admin.";
          _setLoading(false);
          return false;
        }

        // Lock UID in deliveryBoys table
        if (model.uid.isEmpty) {
          await _authRepository.saveDeliveryBoyUid(model.uid, user.uid);
        } else if (model.uid != user.uid) {
          await logout();
          _errorMessage = "Credential mismatch. Contact Admin.";
          _setLoading(false);
          return false;
        }

        _currentUserModel = model;
        _status = AuthStatus.authenticated;
        _setLoading(false);
        notifyListeners();
        return true;
      } 
      
      else if (role == 'admin') {
        if (model == null) {
          await logout();
          _errorMessage = "Access denied. Phone number not whitelisted.";
          _setLoading(false);
          return false;
        }

        if (!model.isActive) {
          await logout();
          _errorMessage = "Administrator account is inactive.";
          _setLoading(false);
          return false;
        }

        _currentUserModel = model;
        _status = AuthStatus.authenticated;
        _setLoading(false);
        notifyListeners();
        return true;
      }

      await logout();
      _errorMessage = "Unknown role selected.";
      _setLoading(false);
      return false;
    } catch (e) {
      await logout();
      _errorMessage = "Verification error: $e";
      _setLoading(false);
      return false;
    }
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _currentUserModel = null;
      notifyListeners();
      return;
    }

    if (_status == AuthStatus.uninitialized || _status == AuthStatus.unauthenticated) {
      final prefs = await SharedPreferences.getInstance();
      final savedRole = prefs.getString('selected_role') ?? 'customer';
      _selectedRole = savedRole;
      await _verifyUserRoleAndInitialize(user, savedRole);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
