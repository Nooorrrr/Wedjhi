import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_text_field.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _statusMessage = '';
      });

      try {
        final email = _emailController.text.trim();
        final success = await authService.resetPassword(email);

        setState(() {
          _isLoading = false;
          _isSuccess = success;
          if (success) {
            _statusMessage = 'Reset email sent. Please check your inbox.';
          } else {
            _statusMessage =
                'Failed to send reset email. Please check if the email is registered.';
          }
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _statusMessage = 'An error occurred: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button at the top
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                      iconSize: 28,
                      color: AppColors.primary,
                    ),
                  ),

                  // Main content
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Reset Password',
                      style: AppTextStyles.headline2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Enter your email for a password reset link',
                        style: AppTextStyles.subtitle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EmailField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          isLastField: true,
                          onEditingComplete: _resetPassword,
                        ),
                        const SizedBox(height: 24),
                        if (_statusMessage.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _isSuccess
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isSuccess
                                    ? AppColors.success.withOpacity(0.5)
                                    : AppColors.error.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color: _isSuccess
                                      ? AppColors.success
                                      : AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _statusMessage,
                                    style: TextStyle(
                                      color: _isSuccess
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        AppButton(
                          text: 'Send Reset Link',
                          icon: Icons.send,
                          isLoading: _isLoading,
                          onPressed: _resetPassword,
                        ),
                        if (_isSuccess)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: AppOutlinedButton(
                              text: 'Back to Login',
                              icon: Icons.arrow_back,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom spacing
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
