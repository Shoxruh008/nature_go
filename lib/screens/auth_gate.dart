import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'main_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Har build'da yangi stream yaratilib, spinner yonib qolmasligi uchun saqlanadi.
  late final Stream<User?> _userStream = AuthService.instance.userChanges();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.instance.busy,
      builder: (context, busy, _) => StreamBuilder<User?>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppTheme.bg,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2.5,
                ),
              ),
            );
          }

          // Ro'yxatdan o'tish/kirish tugamaguncha AuthScreen'da qolamiz.
          final user = snapshot.data;
          final isRegistered = !busy && user != null && !user.isAnonymous;
          return isRegistered ? const MainShell() : const AuthScreen();
        },
      ),
    );
  }
}
