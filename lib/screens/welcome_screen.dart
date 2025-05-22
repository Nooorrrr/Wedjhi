import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../services/database_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'package:flutter/foundation.dart';

class WelcomeScreen extends StatelessWidget {
  final CameraDescription camera;

  const WelcomeScreen({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppPadding.screen,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.face,
                  size: 70,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              // App title
              Text(
                'FaceAuth',
                style: AppTextStyles.headline1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Short tagline
              Text(
                'Secure face recognition login',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              // Buttons
              AppButton(
                text: 'Login',
                icon: Icons.login,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(camera: camera),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              AppOutlinedButton(
                text: 'Create Account',
                icon: Icons.person_add,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SignupScreen(camera: camera),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              // Version text at bottom
              const Text(
                'v1.0',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoCameraScreen extends StatelessWidget {
  const NoCameraScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Camera Error'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: 24),
              Text(
                'No Camera Available',
                style: AppTextStyles.headline2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This app requires a camera to function.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              AppButton(
                text: 'Exit App',
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
