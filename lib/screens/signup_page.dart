import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import '../viewmodels/auth_viewmodel.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    if (email.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    if (password.isEmpty) {
      _showError('Please enter a password');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    final authVm = context.read<AuthViewModel>();
    final success = await authVm.signUp(email, password, name);

    if (success && mounted) {
      // AuthGate will handle navigation based on role
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted && authVm.error != null) {
      _showError(authVm.error!);
      authVm.clearError();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.blue),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: kBackground,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/images/isdex_logo.png',
                                  height: 40,
                                  width: 40,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'IsDex',
                                style: TextStyle(
                                  color: kDarkNavy,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: kLightBlue,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: kDarkNavy,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Name',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Enter username',
                            controller: _nameController,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Email',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Enter email',
                            keyboardType: TextInputType.emailAddress,
                            controller: _emailController,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Enter password',
                            obscure: true,
                            controller: _passwordController,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Enter Password Again',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Re-enter password to confirm',
                            obscure: true,
                            controller: _confirmPasswordController,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: authVm.isLoading ? null : _handleSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccentBlue,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: authVm.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: kDarkNavy,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Welcome Diver!',
                                      style: TextStyle(
                                        color: kDarkNavy,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final TextEditingController? controller;

  const _FormField({
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}