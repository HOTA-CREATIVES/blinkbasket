import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Uploads images to Cloudinary using a signature computed server-side by
/// the `getCloudinarySignature` Cloud Function — the API secret never ships
/// inside the client binary.
class CloudinaryService {
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Uploads an image file to Cloudinary using signed authentication.
  /// Returns the secure URL of the uploaded image on success, or null on failure.
  Future<String?> uploadImage(File file) async {
    return uploadBytes(await file.readAsBytes(), filename: file.path.split(RegExp(r'[\\/]')).last);
  }

  /// Same upload from raw bytes — the only form that works on web, where
  /// `dart:io` File paths don't exist. Prefer this with `XFile.readAsBytes()`.
  Future<String?> uploadBytes(Uint8List bytes, {required String filename}) async {
    try {
      final callable = _functions.httpsCallable('getCloudinarySignature');
      final signatureResult = await callable.call<Map<String, dynamic>>();
      final sig = signatureResult.data;
      final cloudName = sig['cloudName'] as String;
      final apiKey = sig['apiKey'] as String;
      final folder = sig['folder'] as String;
      final signature = sig['signature'] as String;
      final timestamp = sig['timestamp'].toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['folder'] = folder
        ..fields['signature'] = signature
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['secure_url'] as String?;
      } else {
        final errorData = await response.stream.bytesToString();
        debugPrint('Cloudinary upload error: $errorData');
        String errMsg = errorData;
        try {
          final errJson = jsonDecode(errorData);
          errMsg = errJson['error']?['message'] ?? errorData;
        } catch (_) {}
        throw Exception(errMsg);
      }
    } catch (e) {
      debugPrint('Cloudinary Service Exception: $e');
      rethrow;
    }
  }
}
