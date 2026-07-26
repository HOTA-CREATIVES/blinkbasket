import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth/login_with_email_usecase.dart';
import '../../domain/usecases/auth/login_with_google_usecase.dart';
import '../../domain/usecases/auth/register_customer_usecase.dart';
import '../../domain/usecases/auth/setup_customer_profile_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/discover_user_role_usecase.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../services/push_notification_service.dart';

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
  late final SetupCustomerProfileUseCase _setupCustomerProfileUseCase;
  late final LogoutUseCase _logoutUseCase;
  late final DiscoverUserRoleUseCase _discoverUserRoleUseCase;

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _loginWithEmailUseCase = LoginWithEmailUseCase(_authRepository);
    _loginWithGoogleUseCase = LoginWithGoogleUseCase(_authRepository);
    _registerCustomerUseCase = RegisterCustomerUseCase(_authRepository);
    _setupCustomerProfileUseCase = SetupCustomerProfileUseCase(_authRepository);
    _logoutUseCase = LogoutUseCase(_authRepository);
    _discoverUserRoleUseCase = DiscoverUserRoleUseCase(_authRepository);

    _authRepository.authStateChanges.listen(_onAuthStateChanged);
  }

  // Getters
  AuthStatus get status => _status;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedRole => _currentUserModel?.role;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void updateCurrentUserModel(UserModel updatedUser) {
    _currentUserModel = updatedUser;
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

    _status = AuthStatus.needsProfileSetup;
    _setLoading(false);
    return true;
  }

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _loginWithEmailUseCase(email, password);

    if (!result.isSuccess) {
      _errorMessage = result.errorMessage;
      _setLoading(false);
      return false;
    }

    final user = result.user;
    if (user != null) {
      return await _discoverRoleAndInitialize(user);
    }

    _setLoading(false);
    return false;
  }

  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _loginWithGoogleUseCase();

    if (!result.isSuccess) {
      _errorMessage = result.errorMessage;
      _setLoading(false);
      return false;
    }

    final user = result.user;
    if (user != null) {
      return await _discoverRoleAndInitialize(user);
    }

    _setLoading(false);
    return false;
  }

  Future<bool> setupCustomerProfile({
    required String name,
    required String village,
    required String phone,
    String? mandal,
    String? district,
    String? deliveryZoneId,
    bool deliveryAvailable = true,
    AddressModel? defaultAddress,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _errorMessage = "No authenticated user session found.";
      return false;
    }

    _setLoading(true);
    final now = DateTime.now();
    final List<AddressModel> initialAddresses = defaultAddress != null ? [defaultAddress] : [];

    final userModel = UserModel(
      uid: user.uid,
      docId: user.uid,
      name: name,
      email: user.email ?? '',
      phone: phone,
      village: village,
      mandal: mandal ?? 'Undi',
      district: district ?? 'West Godavari',
      deliveryAvailable: deliveryAvailable,
      deliveryZoneId: deliveryZoneId ?? 'zone_west_godavari_1',
      role: 'customer',
      isActive: true,
      onboardingCompleted: true,
      onboardingStep: 3,
      createdAt: now,
      updatedAt: now,
      addresses: initialAddresses,
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

  Future<bool> addAddress(AddressModel address) async {
    if (_currentUserModel == null) {
      _errorMessage = "No authenticated user profile found.";
      return false;
    }
    final updatedAddresses = List<AddressModel>.from(_currentUserModel!.addresses)..add(address);
    final updatedUser = _currentUserModel!.copyWith(addresses: updatedAddresses);
    return await _updateUserModel(updatedUser);
  }

  Future<bool> updateAddress(AddressModel address) async {
    if (_currentUserModel == null) {
      _errorMessage = "No authenticated user profile found.";
      return false;
    }
    final updatedAddresses = _currentUserModel!.addresses.map((a) {
      return a.id == address.id ? address : a;
    }).toList();
    final updatedUser = _currentUserModel!.copyWith(addresses: updatedAddresses);
    return await _updateUserModel(updatedUser);
  }

  Future<bool> deleteAddress(String addressId) async {
    if (_currentUserModel == null) {
      _errorMessage = "No authenticated user profile found.";
      return false;
    }
    final updatedAddresses = _currentUserModel!.addresses.where((a) => a.id != addressId).toList();
    final updatedUser = _currentUserModel!.copyWith(addresses: updatedAddresses);
    return await _updateUserModel(updatedUser);
  }

  Future<bool> _updateUserModel(UserModel userModel) async {
    _setLoading(true);
    final success = await _setupCustomerProfileUseCase(userModel);
    if (success) {
      _currentUserModel = userModel;
      _setLoading(false);
      notifyListeners();
      return true;
    } else {
      _errorMessage = "Failed to update address.";
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    await PushNotificationService.instance.unregisterCurrentDevice(_currentUserModel);
    await _logoutUseCase();
    _currentUserModel = null;
    _status = AuthStatus.unauthenticated;
    _setLoading(false);
  }

  Future<bool> _discoverRoleAndInitialize(User user) async {
    try {
      final model = await _discoverUserRoleUseCase(user.uid, user.email ?? '');

      if (model == null) {
        _status = AuthStatus.needsProfileSetup;
        _setLoading(false);
        notifyListeners();
        return true;
      }

      if (model.role == 'customer' && !model.onboardingCompleted) {
        _currentUserModel = model;
        _status = AuthStatus.needsProfileSetup;
        _setLoading(false);
        notifyListeners();
        return true;
      }

      if (!model.isActive) {
        await logout();
        if (model.role == 'customer') {
          _errorMessage = "Your account is deactivated. Contact support.";
        } else if (model.role == 'delivery') {
          _errorMessage = "Delivery partner account is inactive. Contact Admin.";
        } else if (model.role == 'admin') {
          _errorMessage = "Administrator account is inactive.";
        } else {
          _errorMessage = "Account is inactive.";
        }
        _setLoading(false);
        return false;
      }

      if (model.role == 'delivery') {
        if (model.uid.isEmpty) {
          await _authRepository.saveDeliveryBoyUid(model.docId ?? model.uid, user.uid);
          _currentUserModel = model.copyWith(uid: user.uid);
        } else if (model.uid != user.uid) {
          await logout();
          _errorMessage = "Credential mismatch. Contact Admin.";
          _setLoading(false);
          return false;
        } else {
          _currentUserModel = model;
        }
      } else {
        _currentUserModel = model;
      }

      _status = AuthStatus.authenticated;
      _setLoading(false);
      notifyListeners();

      if (model.role != 'admin') {
        unawaited(PushNotificationService.instance.registerForUser(_currentUserModel!));
      }
      return true;
    } catch (e) {
      await logout();
      _errorMessage = "Verification error: $e";
      _setLoading(false);
      return false;
    }
  }

  Future<void> reloadUserProfile() async {
    final user = _authRepository.currentUser;
    final role = _currentUserModel?.role;
    if (user != null && role != null) {
      final model = await _authRepository.getUserProfile(user.uid, role);
      if (model != null) {
        _currentUserModel = model;
        notifyListeners();
      }
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
      await _discoverRoleAndInitialize(user);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
