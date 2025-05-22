import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_text_field.dart';
import '../services/auth_service.dart';
import 'face_recognition_screen.dart';
import 'face_capture_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  final CameraDescription camera;

  const SignupScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isLoading = false;
  String _errorMessage = '';
  String? _faceImageBase64;
  bool _hasFaceImage = false;
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _captureFace() async {
    try {
      // Navigate to face capture screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceCaptureScreen(
            camera: widget.camera,
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        ),
      );

      // Check if we got a result
      if (result != null &&
          result['success'] == true &&
          result['base64Image'] != null) {
        setState(() {
          _faceImageBase64 = result['base64Image'];
          _hasFaceImage = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face photo captured successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print("Error during face capture: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing face: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if face image is captured
    if (_faceImageBase64 == null || !_hasFaceImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please capture your face photo for facial recognition'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final success = await authService.signUp(
        email: email,
        password: password,
        faceImageBase64: _faceImageBase64,
      );

      if (success) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => FaceRecognitionScreen(camera: widget.camera),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = 'Signup failed. The email may already be in use.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // App Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Create Account',
                      style: AppTextStyles.headline2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to get started',
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 40),
                    // Signup Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          EmailField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            onEditingComplete: () {
                              FocusScope.of(context)
                                  .requestFocus(_passwordFocusNode);
                            },
                          ),
                          PasswordField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            onEditingComplete: () {
                              FocusScope.of(context)
                                  .requestFocus(_confirmPasswordFocusNode);
                            },
                          ),
                          ConfirmPasswordField(
                            controller: _confirmPasswordController,
                            passwordController: _passwordController,
                            focusNode: _confirmPasswordFocusNode,
                            onEditingComplete: () {
                              FocusScope.of(context).unfocus();
                            },
                          ),

                          // Face capture button
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: _hasFaceImage
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _hasFaceImage
                                    ? AppColors.success
                                    : AppColors.divider,
                                width: _hasFaceImage ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _hasFaceImage
                                      ? AppColors.success.withOpacity(0.2)
                                      : AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _hasFaceImage
                                      ? Icons.check_circle
                                      : Icons.face,
                                  color: _hasFaceImage
                                      ? AppColors.success
                                      : AppColors.primary,
                                  size: 30,
                                ),
                              ),
                              title: Text(
                                _hasFaceImage
                                    ? 'Face Photo Captured'
                                    : 'Capture Face Photo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _hasFaceImage
                                      ? AppColors.success
                                      : AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                _hasFaceImage
                                    ? 'Your face photo has been captured successfully'
                                    : 'Required for facial recognition login',
                                style: TextStyle(
                                  color: _hasFaceImage
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  _hasFaceImage
                                      ? Icons.refresh
                                      : Icons.camera_alt,
                                  color: _hasFaceImage
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                                onPressed: _captureFace,
                              ),
                              onTap: _captureFace,
                            ),
                          ),

                          const SizedBox(height: 24),
                          if (_errorMessage.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          AppButton(
                            text: 'Create Account',
                            icon: Icons.person_add,
                            isLoading: _isLoading,
                            onPressed: _signup,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    LoginScreen(camera: widget.camera),
                              ),
                            );
                          },
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
