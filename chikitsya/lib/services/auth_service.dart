import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? _verificationId;

  /// Login state
  static bool get isLoggedIn => _auth.currentUser != null;

  /// Step 1: Send OTP
  static Future<void> sendOtp({
    required String phoneNumber,
    required Function() onCodeSent,
    required Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),

      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification (Android only)
        await _auth.signInWithCredential(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? "OTP verification failed");
      },

      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent();
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Step 2: Verify OTP
  static Future<void> verifyOtp({
    required String otp,
    required Function() onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      if (_verificationId == null) {
        onError("Verification ID not found");
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);
      onSuccess();
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? "Invalid OTP");
    }
  }

  /// Logout
  static Future<void> logout() async {
    await _auth.signOut();
  }
}
