import 'package:flutter/material.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/push_notification_service.dart';
import 'auth_provider.dart';

class ProfileProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final AuthProvider authProvider;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  ProfileProvider({
    required this.authProvider,
    AuthRepository? repository,
  }) : _authRepository = repository ?? _defaultRepository();

  static AuthRepository _defaultRepository() {
    throw UnimplementedError(
      'ProfileProvider needs an injected AuthRepository. '
      'Wire one in main.dart MultiProvider.',
    );
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Update name, phone, village, and optionally avatarUrl
  Future<bool> updateProfileDetails({
    required String name,
    required String phone,
    required String village,
    String? avatarUrl,
    String? vehicleDetails,
    String? vehicleNo,
    String? licenseNo,
  }) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;
    _successMessage = null;

    final updatedUser = currentUser.copyWith(
      name: name,
      phone: phone,
      village: village,
      avatarUrl: avatarUrl ?? currentUser.avatarUrl,
      vehicleDetails: vehicleDetails ?? currentUser.vehicleDetails,
      vehicleNo: vehicleNo ?? currentUser.vehicleNo,
      licenseNo: licenseNo ?? currentUser.licenseNo,
    );

    final success = await _authRepository.updateUserProfile(updatedUser);

    if (success) {
      authProvider.updateCurrentUserModel(updatedUser);
      _successMessage = "Profile updated successfully!";
      _setLoading(false);
      return true;
    } else {
      _errorMessage = "Failed to update profile details in database.";
      _setLoading(false);
      return false;
    }
  }

  // Remove profile photo
  Future<bool> deleteAvatar() async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    final updatedUser = currentUser.copyWith(avatarUrl: "");
    final success = await _authRepository.updateUserProfile(updatedUser);

    if (success) {
      authProvider.updateCurrentUserModel(updatedUser);
      _successMessage = "Profile picture removed.";
      _setLoading(false);
      return true;
    } else {
      _errorMessage = "Failed to remove profile picture.";
      _setLoading(false);
      return false;
    }
  }

  // Update avatar URL specifically
  Future<bool> updateAvatar(String avatarUrl) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    final updatedUser = currentUser.copyWith(avatarUrl: avatarUrl);
    final success = await _authRepository.updateUserProfile(updatedUser);

    if (success) {
      authProvider.updateCurrentUserModel(updatedUser);
      _successMessage = "Profile picture updated!";
      _setLoading(false);
      return true;
    } else {
      _errorMessage = "Failed to update profile picture.";
      _setLoading(false);
      return false;
    }
  }

  // Add a new shipping/delivery address
  Future<bool> addAddress(AddressModel address) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    // A newly added address the user flagged default demotes the old one; the
    // very first address becomes default automatically.
    final base = address.isDefault
        ? currentUser.addresses.map((a) => a.withDefault(false)).toList()
        : List<AddressModel>.from(currentUser.addresses);
    final updatedAddresses = AddressModel.normalizeDefaults([...base, address]);
    final updatedUser = currentUser.copyWith(addresses: updatedAddresses);

    final success = await _authRepository.updateUserProfile(updatedUser);

    if (success) {
      authProvider.updateCurrentUserModel(updatedUser);
      _successMessage = "Address added successfully!";
      _setLoading(false);
      return true;
    } else {
      _errorMessage = "Failed to add address.";
      _setLoading(false);
      return false;
    }
  }

  // Update an existing address
  Future<bool> updateAddress(AddressModel address) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    final updatedAddresses = AddressModel.normalizeDefaults(
      currentUser.addresses.map((a) {
        if (a.id == address.id) return address;
        // Editing an address into the default demotes the others.
        return address.isDefault ? a.withDefault(false) : a;
      }).toList(),
    );
    final updatedUser = currentUser.copyWith(addresses: updatedAddresses);

    final success = await _authRepository.updateUserProfile(updatedUser);

    if (success) {
      authProvider.updateCurrentUserModel(updatedUser);
      _successMessage = "Address updated successfully!";
      _setLoading(false);
      return true;
    } else {
      _errorMessage = "Failed to update address.";
      _setLoading(false);
      return false;
    }
  }

  // Make one saved address the default (checkout pre-selects it).
  Future<bool> setDefaultAddress(String addressId) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    final updatedAddresses = [
      for (final a in currentUser.addresses) a.withDefault(a.id == addressId),
    ];
    final updatedUser = currentUser.copyWith(addresses: updatedAddresses);

    // Optimistic, reverted on failure (same pattern as toggleFavorite).
    authProvider.updateCurrentUserModel(updatedUser);
    final success = await _authRepository.updateUserProfile(updatedUser);
    if (!success) {
      authProvider.updateCurrentUserModel(currentUser);
      _errorMessage = "Failed to set default address.";
      notifyListeners();
    }
    return success;
  }

  // Delete an address
  Future<bool> deleteAddress(String addressId) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    // If the deleted one was the default, the next address is promoted.
    final updatedAddresses = AddressModel.normalizeDefaults(
      currentUser.addresses.where((a) => a.id != addressId).toList(),
    );
    final updatedUser = currentUser.copyWith(addresses: updatedAddresses);

    final success = await _authRepository.updateUserProfile(updatedUser);

    if (success) {
      authProvider.updateCurrentUserModel(updatedUser);
      _successMessage = "Address deleted successfully!";
      _setLoading(false);
      return true;
    } else {
      _errorMessage = "Failed to delete address.";
      _setLoading(false);
      return false;
    }
  }

  // Toggle a product's membership in the signed-in user's wishlist
  Future<bool> toggleFavorite(String productId) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    final currentFavorites = List<String>.from(currentUser.favoriteProductIds);
    if (currentFavorites.contains(productId)) {
      currentFavorites.remove(productId);
    } else {
      currentFavorites.add(productId);
    }
    final updatedUser = currentUser.copyWith(favoriteProductIds: currentFavorites);

    // Optimistic update so the heart toggles instantly; no loading spinner needed.
    authProvider.updateCurrentUserModel(updatedUser);
    final success = await _authRepository.updateUserProfile(updatedUser);

    if (!success) {
      authProvider.updateCurrentUserModel(currentUser);
      _errorMessage = "Failed to update wishlist.";
      notifyListeners();
    }
    return success;
  }

  // Toggle order-status push notifications for the signed-in user.
  // Persists the preference AND registers/unregisters this device's FCM token
  // so the change takes real effect (no token -> Cloud Functions can't push).
  Future<bool> setNotificationsEnabled(bool enabled) async {
    final currentUser = authProvider.currentUserModel;
    if (currentUser == null) {
      _errorMessage = "No active user session found.";
      notifyListeners();
      return false;
    }

    final updatedUser = currentUser.copyWith(notificationsEnabled: enabled);

    // Optimistic UI so the switch flips instantly.
    authProvider.updateCurrentUserModel(updatedUser);

    // Persist the flag FIRST. updateUserProfile does a full-document set() that
    // rewrites fcmTokens, so the arrayUnion/arrayRemove token op must run AFTER
    // it or the set() would clobber the token change.
    final success = await _authRepository.updateUserProfile(updatedUser);

    if (!success) {
      authProvider.updateCurrentUserModel(currentUser);
      _errorMessage = "Failed to update notification settings.";
      notifyListeners();
      return false;
    }

    if (enabled) {
      await PushNotificationService.instance.registerForUser(updatedUser);
    } else {
      await PushNotificationService.instance.unregisterCurrentDevice(updatedUser);
    }
    return true;
  }
}