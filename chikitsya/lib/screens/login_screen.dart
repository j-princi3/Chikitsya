import 'package:chikitsya/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  bool otpSent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              /// Logo
              Center(
                child: Column(
                  children: const [
                    Icon(Icons.health_and_safety, size: 64, color: Colors.teal),
                    SizedBox(height: 12),
                    Text(
                      "Chikitsya",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Secure access to your care plan",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              /// Phone Field
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Mobile Number",
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// OTP Field
              if (otpSent)
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "OTP",
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              /// Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (!otpSent) {
                      if (phoneController.text.isEmpty) return;

                      final fullPhone = "+91${phoneController.text.trim()}";

                      await AuthService.sendOtp(
                        phoneNumber: fullPhone,
                        onCodeSent: () {
                          setState(() => otpSent = true);
                        },
                        onError: (error) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        },
                      );
                    } else {
                      if (otpController.text.isEmpty) return;

                      final fullPhone = "+91${phoneController.text.trim()}";

                      await AuthService.verifyOtp(
                        otp: otpController.text.trim(),
                        onSuccess: () {
                          // Persist the user's phone for the profile page.
                          context.read<ProfileProvider>().setPhoneNumber(fullPhone);
                          context
                              .read<ProfileProvider>()
                              .refreshFromAuth(fallbackPhoneNumber: fullPhone);
                          Navigator.pop(context);
                          widget.onLoginSuccess?.call();
                        },
                        onError: (error) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                        },
                      );
                    }
                  },

                  child: Text(
                    otpSent ? "Verify & Continue" : "Send OTP",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  "Your data is private & secure",
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
