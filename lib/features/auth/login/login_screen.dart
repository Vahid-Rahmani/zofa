import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/app_controller.dart';
import '../../../core/state/ui_translation_controller.dart';
import '../../../core/theme/zova_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/tr_text.dart';
import '../../../core/widgets/zova_logo.dart';

/// Email + password sign in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onRegister});

  final VoidCallback onRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<AppController>();
    try {
      await controller.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppController>().busy;
    context.watch<UiTranslationController?>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Center(child: ZovaLogo(size: 72)),
                const SizedBox(height: 40),
                const TrText(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: ZovaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const TrText(
                  'Sign in to continue your streak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ZovaColors.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Email'),
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return context.tr('Enter a valid email');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: context.tr('Password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return context.tr('At least 6 characters');
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: ZovaColors.error),
                  ),
                ],
                const SizedBox(height: 28),
                GradientButton(
                  label: context.tr('Sign in'),
                  loading: busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TrText(
                      'New to zova?',
                      style: TextStyle(color: ZovaColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: busy ? null : widget.onRegister,
                      child: const TrText('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
