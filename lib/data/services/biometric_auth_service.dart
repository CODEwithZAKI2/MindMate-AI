import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Service for biometric/PIN authentication for locked journal entries
class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device supports biometric authentication
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticate user with biometric or device credentials
  /// Returns true if authentication successful
  Future<bool> authenticate({
    String reason = 'Please authenticate to view this entry',
  }) async {
    try {
      final isAvailable = await this.isAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      // Handle specific errors
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        return false;
      }
      rethrow;
    }
  }

  /// Quick check if entry should show lock UI
  Future<bool> shouldShowLockUI() async {
    return await isAvailable();
  }
}
