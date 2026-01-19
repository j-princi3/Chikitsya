import 'package:chikitsya/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import '../providers/profile_provider.dart';

void requireLogin(
  BuildContext context, {
  required VoidCallback onAuthenticated,
}) {
  if (AuthService.isLoggedIn) {
    onAuthenticated();
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: () {
            // Sync persisted profile state with the newly authenticated user.
            context.read<ProfileProvider>().refreshFromAuth();
            onAuthenticated();
          },
        ),
      ),
    );
  }
}
