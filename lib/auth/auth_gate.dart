import 'package:flutter/material.dart';

import '../pages/auth_page.dart';
import 'auth_service.dart';

class AuthGate extends StatelessWidget {
  final AuthService authService;
  final Widget signedInChild;

  const AuthGate({
    super.key,
    required this.authService,
    required this.signedInChild,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: authService.authStateChanges,
      initialData: authService.hasSession,
      builder: (context, snapshot) {
        if (snapshot.data == true) return signedInChild;
        return AuthPage(authService: authService);
      },
    );
  }
}
