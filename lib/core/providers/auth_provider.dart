import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth/login_with_email_usecase.dart';
import '../../domain/usecases/auth/login_with_google_usecase.dart';
import '../../domain/usecases/auth/register_customer_usecase.dart';
import '../../domain/usecases/auth/setup_customer_profile_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/discover_user_role_usecase.dart';
import '../services/push_notification_service.dart';
import '../utils/app_exception.dart';

enum AuthStatus {
  uninitialized,
  authenticating,
  authenticated,
  unauthenticated,
  needsProfileSetup,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

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
  StreamSubscription<User?>? _authSub;
  Timer? _tokenRefreshTicker;

  AuthProvider({AuthRepository? repository})
      : _authRepository = repository ?? _defaultRepository() {
    _loginWithEmailUseCase = LoginWithEmailUseCase(_authRepository);
    _loginWithGoogleUseCase = LoginWithGoogleUseCase(_authRepository);
    _registerCustomerUseCase = RegisterCustomerUseCase(_authRepository);
    _setupCustomerProfileUseCase = SetupCustomerProfileUseCase(_authRepository);
    _logoutUseCase = LogoutUseCase(_authRepository);
    _discoverUserRoleUseCase = DiscoverUserRoleUseCase(_authRepository);

    _authSub = _authRepository.authStateChanges.listen(_onAuthStateChanged);
    // Token-refresh re-evaluation: Firebase Auth tokens expire after ~1h.
    // Refresh events don't emit on `authStateChanges` (only sign-in/out do),
    // so poll on a slow cadence and re-resolve the live role from Firestore.
    _tokenRefreshTicker = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _onAuthStateChanged(_authRepository.currentUser, forceRefresh: true),
    );
  }

  static AuthRepository _defaultRepository() {
    // Lazy import to avoid a hard dep on firebase in unit tests; tests must
    // always inject a fake via the constructor.
    throw UnimplementedError(
      'AuthProvider needs an injected AuthRepository. '
      'Wire one in main.dart MultiProvider.',
    );
  }

  // Getters
  AuthStatus get status => _status;
  UserModel? get currentUserModel => _currentUserModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get hasActiveSession => _currentUserModel != null || _authRepository.currentUser != null;

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

  /// Whether the signed-in account has verified its email (see
  /// [AuthRepository.isEmailVerified]).
  bool get isEmailVerified => _authRepository.isEmailVerified;

  bool _isSendingVerification = false;
  bool _isCheckingVerification = false;
  bool get isSendingVerification => _isSendingVerification;
  bool get isCheckingVerification => _isCheckingVerification;

  /// Sends the verification link. Returns null on success, else a message.
  Future<String?> resendVerificationEmail() async {
    if (_isSendingVerification) return null;
    _isSendingVerification = true;
    notifyListeners();
    final error = await _authRepository.sendEmailVerification();
    _isSendingVerification = false;
    notifyListeners();
    return error;
  }

  /// Re-checks verification after the user taps the emailed link.
  Future<bool> refreshEmailVerified() async {
    if (_isCheckingVerification) return isEmailVerified;
    _isCheckingVerification = true;
    notifyListeners();
    final verified = await _authRepository.refreshEmailVerification();
    _isCheckingVerification = false;
    notifyListeners();
    return verified;
  }

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;
    final ok = await _authRepository.sendPasswordReset(email);
    _setLoading(false);
    if (!ok) {
      _errorMessage =
          "We couldn't send a reset email. Check the address and try again.";
    }
    return ok;
  }

  Future<bool> setupCustomerProfile({
    required String name,
    required String phone,
    required String village,
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
    final List<AddressModel> initialAddresses =
        defaultAddress != null ? [defaultAddress] : const [];

    final userModel = UserModel(
      uid: user.uid,
      docId: user.uid,
      name: name,
      email: user.email ?? '',
      phone: phone,
      avatarUrl: _currentUserModel?.avatarUrl ?? user.photoURL,
      village: village,
      mandal: mandal ?? '',
      district: district ?? '',
      deliveryAvailable: deliveryAvailable,
      deliveryZoneId: deliveryZoneId ?? '',
      role: 'customer',
      isActive: true,
      onboardingCompleted: true,
      onboardingStep: 3,
      createdAt: _currentUserModel?.createdAt ?? now,
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

  Future<void> logout() async {
    _setLoading(true);
    await PushNotificationService.instance
        .unregisterCurrentDevice(_currentUserModel);
    await _logoutUseCase();
    _currentUserModel = null;
    _status = AuthStatus.unauthenticated;
    _setLoading(false);
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await PushNotificationService.instance
          .unregisterCurrentDevice(_currentUserModel);
      final error = await _authRepository.deleteAccount();
      if (error == null) {
        _currentUserModel = null;
        _status = AuthStatus.unauthenticated;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = error;
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = userMessageFor(e, fallback: "Account deletion failed. Please try again.");
      _setLoading(false);
      return false;
    }
  }

  // Both an explicit loginWith*() call and the authStateChanges listener
  // race to call this on a fresh sign-in — collapse concurrent calls into
  // the one in-flight run so role discovery / push registration / stub
  // writes never fire twice for the same sign-in.
  Future<bool>? _discoverInFlight;

  Future<bool> _discoverRoleAndInitialize(User user) {
    return _discoverInFlight ??=
        _doDiscoverRoleAndInitialize(user).whenComplete(() {
      _discoverInFlight = null;
    });
  }

  Future<bool> _doDiscoverRoleAndInitialize(User user) async {
    try {
      final model = await _discoverUserRoleUseCase(user.uid, user.email ?? '');

      if (model == null) {
        _currentUserModel = UserModel(
          uid: user.uid,
          docId: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          phone: user.phoneNumber ?? '',
          avatarUrl: user.photoURL,
          village: '',
          role: 'customer',
          isActive: true,
          onboardingCompleted: false,
          onboardingStep: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
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
          _errorMessage =
              "Delivery partner account is inactive. Contact Admin.";
        } else if (model.role == 'admin') {
          _errorMessage = "Administrator account is inactive.";
        } else {
          _errorMessage = "Account is inactive.";
        }
        _setLoading(false);
        return false;
      }

      if (model.role == 'delivery') {
        // All riders are provisioned via createRiderLogin (docId == UID).
        // If the doc was found by email lookup and the UID doesn't match yet,
        // the rider needs to be re-provisioned by an admin — there is no
        // client-side migration path.
        if (model.uid.isEmpty || model.uid != user.uid) {
          await logout();
          _errorMessage =
              "Account configuration error. Contact admin to re-provision your login.";
          _setLoading(false);
          return false;
        }
        _currentUserModel = model;
      } else {
        _currentUserModel = model;
      }

      _status = AuthStatus.authenticated;
      _setLoading(false);
      notifyListeners();

      if (model.role != 'admin') {
        unawaited(
          PushNotificationService.instance.registerForUser(_currentUserModel!),
        );
      }
      return true;
    } catch (e) {
      debugPrint('_discoverRoleAndInitialize error: $e');
      await logout();
      _errorMessage = "Something went wrong while signing you in. Please try again.";
      _setLoading(false);
      return false;
    }
  }

  Future<void> reloadUserProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) return;
    final role = _currentUserModel?.role ?? 'customer';
    final model = await _authRepository.refreshUserProfile(user.uid, role);
    if (model != null) {
      if (!model.isActive) {
        await logout();
        return;
      }
      _currentUserModel = model;
      notifyListeners();
    }
  }

  /// Ensures an authenticated user model is present if a Firebase session exists.
  /// Resolves the user profile or falls back to an active customer stub so
  /// checkout and other authorized flows are never blocked by a profile stream glitch.
  Future<UserModel?> ensureCurrentUserModel() async {
    if (_currentUserModel != null) return _currentUserModel;
    final user = _authRepository.currentUser;
    if (user == null) return null;

    try {
      await _discoverRoleAndInitialize(user);
      if (_currentUserModel != null) return _currentUserModel;
    } catch (e) {
      debugPrint('ensureCurrentUserModel error: $e');
    }

    final fallback = UserModel(
      uid: user.uid,
      docId: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      phone: user.phoneNumber ?? '',
      avatarUrl: user.photoURL,
      village: '',
      role: 'customer',
      isActive: true,
      onboardingCompleted: true,
      onboardingStep: 3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _currentUserModel = fallback;
    _status = AuthStatus.authenticated;
    notifyListeners();
    return fallback;
  }

  Future<void> _onAuthStateChanged(User? user,
      {bool forceRefresh = false}) async {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _currentUserModel = null;
      notifyListeners();
      return;
    }

    // Token-refresh ticks ask for a live re-resolution so role flips made
    // from the admin console (e.g. rider deactivation) take effect without
    // forcing a logout.
    if (forceRefresh && _currentUserModel != null) {
      final role = _currentUserModel!.role;
      final live = await _authRepository.refreshUserProfile(user.uid, role);
      if (live != null && !live.isActive) {
        await logout();
        _errorMessage = "Your account was deactivated. Contact support.";
        return;
      }
      if (live != null) {
        _currentUserModel = live;
        notifyListeners();
      }
      return;
    }

    if (_status == AuthStatus.uninitialized ||
        _status == AuthStatus.unauthenticated) {
      await _discoverRoleAndInitialize(user);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSub?.cancel();
    _tokenRefreshTicker?.cancel();
    super.dispose();
  }
}