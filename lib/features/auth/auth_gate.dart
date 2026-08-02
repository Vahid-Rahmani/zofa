import 'package:flutter/material.dart';

import 'login/login_screen.dart';
import 'register/register_screen.dart';

/// Switches between the sign-in and registration forms.
///
/// The gate is replaced by [HomeShell] automatically once the
/// [AppController] reports a signed-in user.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _registering = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _registering
          ? RegisterScreen(
              key: const ValueKey('register'),
              onBack: () => setState(() => _registering = false),
            )
          : LoginScreen(
              key: const ValueKey('login'),
              onRegister: () => setState(() => _registering = true),
            ),
    );
  }
}
