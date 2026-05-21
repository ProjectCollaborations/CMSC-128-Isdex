import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Future<void> _handleSignUp() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showError('Please enter a password');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    final authVm = context.read<AuthViewModel>();
    await authVm.signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
    );

    if (!mounted) return;
    if (authVm.error != null) {
      _showError(authVm.error!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back, color: AppTheme.teal400),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.teal50,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/isdex_logo.png',
                            height: 40,
                            width: 40,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'IsDex',
                          style: TextStyle(
                            color: AppTheme.navy900,
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
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Name',
                      style: TextStyle(
                        color: AppTheme.navy900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FormField(hint: 'Enter username', controller: _nameController),
                    const SizedBox(height: 16),
                    const Text(
                      'Email',
                      style: TextStyle(
                        color: AppTheme.navy900,
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
                        color: AppTheme.navy900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FormField(hint: 'Enter password', obscure: true, controller: _passwordController),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter Password Again',
                      style: TextStyle(
                        color: AppTheme.navy900,
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
                        child: authVm.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: AppTheme.teal400,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Welcome Diver!'),
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
        hintText: hint,
      ),
    );
  }
}
