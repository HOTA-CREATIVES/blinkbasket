import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/models/user_model.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(isSuccess: true, user: credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: _getReadableFirebaseAuthError(e.code),
      );
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<AuthResult> registerWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(isSuccess: true, user: credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: _getReadableFirebaseAuthError(e.code),
      );
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(isSuccess: false, errorMessage: "Google Sign-In was cancelled.");
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return AuthResult(isSuccess: true, user: userCredential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: _getReadableFirebaseAuthError(e.code),
      );
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  @override
  Future<UserModel?> discoverUserRole(String uid, String email) async {
    final normalizedEmail = email.toLowerCase().trim();

    // Priority 1: Admin
    try {
      final adminDoc = await _firestore.collection('admins').doc(uid).get();
      if (adminDoc.exists && adminDoc.data() != null) {
        return UserModel.fromMap({...adminDoc.data()!, 'role': 'admin'}, adminDoc.id);
      }
    } catch (e) {
      debugPrint('discoverUserRole admin by UID check note: $e');
    }

    if (normalizedEmail.isNotEmpty) {
      try {
        final adminEmailQuery = await _firestore
            .collection('admins')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (adminEmailQuery.docs.isNotEmpty) {
          final doc = adminEmailQuery.docs.first;
          return UserModel.fromMap({...doc.data(), 'role': 'admin'}, doc.id);
        }
      } catch (e) {
        debugPrint('discoverUserRole admin by email check note: $e');
      }
    }

    // Priority 2: Delivery partner
    if (normalizedEmail.isNotEmpty) {
      try {
        var deliveryQuery = await _firestore
            .collection('deliveryPartners')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (deliveryQuery.docs.isEmpty) {
          deliveryQuery = await _firestore
              .collection('deliveryBoys')
              .where('email', isEqualTo: normalizedEmail)
              .limit(1)
              .get();
        }
        if (deliveryQuery.docs.isNotEmpty) {
          final doc = deliveryQuery.docs.first;
          return UserModel.fromMap({...doc.data(), 'role': 'delivery'}, doc.id);
        }
      } catch (e) {
        debugPrint('discoverUserRole delivery check note: $e');
      }
    }

    // Priority 3: Customer
    try {
      final customerDoc = await _firestore.collection('users').doc(uid).get();
      if (customerDoc.exists && customerDoc.data() != null) {
        return UserModel.fromMap(customerDoc.data()!, customerDoc.id);
      }
    } catch (e) {
      debugPrint('discoverUserRole customer check note: $e');
    }

    // No doc found → Create initial consistent record for new customer in Firestore
    final user = currentUser;
    final now = DateTime.now();
    final initialDoc = {
      'uid': uid,
      'name': user?.displayName ?? '',
      'email': normalizedEmail,
      'phone': user?.phoneNumber ?? '',
      'role': 'customer',
      'isActive': true,
      'onboardingCompleted': false,
      'onboardingStep': 1,
      'village': '',
      'mandal': 'Undi',
      'district': 'West Godavari',
      'deliveryAvailable': true,
      'deliveryZoneId': 'zone_west_godavari_1',
      'totalOrders': 0,
      'totalSpent': 0.0,
      'firstOrderCompleted': false,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'addresses': [],
    };
    try {
      await _firestore.collection('users').doc(uid).set(initialDoc, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Initial customer doc creation note: $e');
    }

    return null;
  }

  @override
  Future<bool> setupCustomerProfile(UserModel userModel) async {
    try {
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());
      return true;
    } catch (e) {
      debugPrint("Firestore setup profile error: $e");
      return false;
    }
  }

  @override
  Future<bool> updateUserProfile(UserModel userModel) async {
    try {
      if (userModel.role == 'delivery') {
        final String docPath = userModel.docId ?? userModel.uid;
        final updates = {
          'name': userModel.name,
          'phone': userModel.phone,
          'currentVillage': userModel.village,
          if (userModel.avatarUrl != null) 'avatarUrl': userModel.avatarUrl,
          if (userModel.vehicleDetails != null) 'vehicleDetails': userModel.vehicleDetails,
          if (userModel.vehicleNo != null) 'vehicleNo': userModel.vehicleNo,
          if (userModel.licenseNo != null) 'licenseNo': userModel.licenseNo,
        };
        await _firestore.collection('deliveryPartners').doc(docPath).set(updates, SetOptions(merge: true));
        return true;
      }

      if (userModel.role == 'admin') {
        debugPrint("updateUserProfile: admin profile edits are not supported client-side.");
        return false;
      }

      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());
      return true;
    } catch (e) {
      debugPrint("Firestore update profile error: $e");
      return false;
    }
  }

  @override
  Future<UserModel?> getUserProfile(String uid, String role) async {
    try {
      if (role == 'customer') {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data()!, doc.id);
        }
      } else if (role == 'delivery') {
        final user = currentUser;
        final email = user?.email;
        if (email != null) {
          var query = await _firestore
              .collection('deliveryPartners')
              .where('email', isEqualTo: email.toLowerCase().trim())
              .get();
          if (query.docs.isEmpty) {
            query = await _firestore
                .collection('deliveryBoys')
                .where('email', isEqualTo: email.toLowerCase().trim())
                .get();
          }
          if (query.docs.isNotEmpty) {
            final doc = query.docs.first;
            return UserModel.fromMap({...doc.data(), 'role': 'delivery'}, doc.id);
          }
        }
      } else if (role == 'admin') {
        final doc = await _firestore.collection('admins').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap({...doc.data()!, 'role': 'admin'}, doc.id);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveDeliveryBoyUid(String docId, String uid) async {
    final partnerRef = _firestore.collection('deliveryPartners').doc(docId);
    final partnerSnap = await partnerRef.get();
    if (partnerSnap.exists) {
      final data = partnerSnap.data()!;
      await _firestore.collection('deliveryPartners').doc(uid).set({
        ...data,
        'uid': uid,
      });
      if (docId != uid) {
        await partnerRef.delete();
      }
    } else {
      final docRef = _firestore.collection('deliveryBoys').doc(docId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        await _firestore.collection('deliveryPartners').doc(uid).set({
          ...data,
          'uid': uid,
        });
        if (docId != uid) {
          await docRef.delete();
        }
      }
    }
  }

  String _getReadableFirebaseAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found for this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'operation-not-allowed':
        return 'This login method is not enabled.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check and try again.';
      case 'invalid-verification-code':
        return 'The entered OTP code is incorrect. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification request. Please request a new OTP.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
