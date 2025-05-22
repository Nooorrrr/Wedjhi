import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_text_field.dart';
import '../services/auth_service.dart';
import '../services/face_service.dart';
import 'face_capture_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final CameraDescription camera;

  const ProfileScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); // For re-authentication
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _hasFaceImage = false;
  String? _faceImageBase64;
  String _errorMessage = '';
  String _successMessage = '';

  // Section expansion states
  bool _isEmailSectionExpanded = false;
  bool _isUsernameSectionExpanded = false;
  bool _isFaceSectionExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Load current user data
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final userData = await authService.getCurrentUserProfile();

      if (userData != null) {
        setState(() {
          _emailController.text = userData['email'] ?? '';
          _usernameController.text = userData['username'] ?? '';
          _hasFaceImage = userData['faceImageBase64'] != null &&
              userData['faceImageBase64'].toString().isNotEmpty;
        });
        print("User data loaded: ${authService.currentUser?.uid}");
        print("Has face image: $_hasFaceImage");
      } else {
        print("No user data found");
        setState(() {
          _errorMessage = 'Failed to load user data. Please try again.';
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        _errorMessage = 'Error loading user data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update email (requires re-authentication)
  Future<void> _updateEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      // Re-authenticate user
      final success = await authService.updateEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        setState(() {
          _successMessage = 'Email updated successfully';
          _isEmailSectionExpanded = false;
          _passwordController.clear();
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to update email. Please check your password.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating email: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update username
  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a username';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final success =
          await authService.updateUsername(_usernameController.text.trim());

      if (success) {
        setState(() {
          _successMessage = 'Username updated successfully';
          _isUsernameSectionExpanded = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to update username';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating username: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Capture new face image
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
          _errorMessage = '';
          _successMessage = '';
        });

        // Update face image in Firebase
        _updateFaceImage();
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

  // Update face image in Firebase
  Future<void> _updateFaceImage() async {
    if (_faceImageBase64 == null || !_hasFaceImage) {
      setState(() {
        _errorMessage = 'No face image available to update';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final success = await authService.updateFaceImage(_faceImageBase64!);

      if (success) {
        setState(() {
          _successMessage = 'Face image updated successfully';
          _isFaceSectionExpanded = false;
        });

        // Reinitialize face service to load the new reference image
        await faceService.refreshReferenceImage();
      } else {
        setState(() {
          _errorMessage = 'Failed to update face image';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating face image: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Logout function
  Future<void> _logout() async {
    try {
      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );

      // Force a delay to ensure Firebase has time to process
      await Future.delayed(const Duration(milliseconds: 300));

      // Sign out from Firebase
      await authService.signOut();

      if (!mounted) return;

      // Close loading indicator
      Navigator.pop(context);

      // Navigate to welcome screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => WelcomeScreen(camera: widget.camera),
        ),
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      print("Error during logout: $e");

      if (!mounted) return;

      // Close loading indicator if it's showing
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Profile Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // Show confirmation dialog
                bool confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirm) {
                  await _logout();
                }
              },
            ),
          ],
        ),
        body: _isLoading && _emailController.text.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _hasFaceImage ? Icons.face : Icons.person,
                                size: 60,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _usernameController.text.isNotEmpty
                                  ? _usernameController.text
                                  : _emailController.text,
                              style: AppTextStyles.headline2,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              _usernameController.text.isNotEmpty
                                  ? _emailController.text
                                  : '',
                              style: AppTextStyles.subtitle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Status messages
                      if (_errorMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_successMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successMessage,
                                  style: TextStyle(
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Update Email Section
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.email,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: const Text('Email Address'),
                              subtitle: Text(_emailController.text),
                              trailing: IconButton(
                                icon: Icon(
                                  _isEmailSectionExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isEmailSectionExpanded =
                                        !_isEmailSectionExpanded;
                                    if (!_isEmailSectionExpanded) {
                                      _passwordController.clear();
                                    }
                                  });
                                },
                              ),
                            ),
                            if (_isEmailSectionExpanded)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    EmailField(
                                      controller: _emailController,
                                    ),
                                    PasswordField(
                                      controller: _passwordController,
                                      labelText: 'Current Password (to verify)',
                                      isLastField: true,
                                    ),
                                    const SizedBox(height: 16),
                                    AppButton(
                                      text: 'Update Email',
                                      icon: Icons.save,
                                      onPressed: _updateEmail,
                                      isLoading: _isLoading,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Update Username Section
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: const Text('Username'),
                              subtitle: Text(
                                _usernameController.text.isEmpty
                                    ? 'Not set'
                                    : _usernameController.text,
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  _isUsernameSectionExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isUsernameSectionExpanded =
                                        !_isUsernameSectionExpanded;
                                  });
                                },
                              ),
                            ),
                            if (_isUsernameSectionExpanded)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AuthTextField(
                                      controller: _usernameController,
                                      labelText: 'Username',
                                      hintText: 'Enter your preferred username',
                                      prefixIcon: Icons.person,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a username';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    AppButton(
                                      text: 'Update Username',
                                      icon: Icons.save,
                                      onPressed: _updateUsername,
                                      isLoading: _isLoading,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Update Face Image Section
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.face,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: const Text('Face Image'),
                              subtitle: Text(
                                _hasFaceImage
                                    ? 'Face image is set'
                                    : 'No face image set',
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  _isFaceSectionExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isFaceSectionExpanded =
                                        !_isFaceSectionExpanded;
                                  });
                                },
                              ),
                            ),
                            if (_isFaceSectionExpanded)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        leading: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: _hasFaceImage
                                                ? AppColors.success
                                                    .withOpacity(0.2)
                                                : AppColors.primary
                                                    .withOpacity(0.1),
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
                                              ? 'Face Photo Available'
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
                                              ? 'Your face photo is available for recognition'
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
                                    const SizedBox(height: 16),
                                    Text(
                                      'Take a new photo to update your face image for facial recognition. Make sure you are in a well-lit environment and look directly at the camera.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppButton(
                                      text: 'Capture New Image',
                                      icon: Icons.camera_alt,
                                      onPressed: _captureFace,
                                      isLoading: _isLoading,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Logout button
                      AppOutlinedButton(
                        text: 'Logout',
                        icon: Icons.logout,
                        onPressed: () async {
                          // Show confirmation dialog
                          bool confirm = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Logout'),
                                  content: const Text(
                                      'Are you sure you want to logout?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Logout'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (confirm) {
                            await _logout();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
