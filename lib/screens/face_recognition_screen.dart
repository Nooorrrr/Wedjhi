import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../services/auth_service.dart';
import '../services/face_service.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  final CameraDescription camera;

  const FaceRecognitionScreen({Key? key, required this.camera})
      : super(key: key);

  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _resultMessage = 'Initializing...';
  String _statusMessage = 'Loading camera...';
  bool _isFaceDetected = false;
  bool _isRecognized = false;

  // New variable to track face authentication status
  bool _hasFaceAuthenticated = false;

  // Track which camera is active
  CameraDescription? _currentCamera;
  List<CameraDescription> _availableCameras = [];
  bool _isFrontCameraActive = true; // Default to front camera

  // Initialize the system
  Future<void> _initializeSystem() async {
    try {
      setState(() {
        _resultMessage = 'Loading system...';
        _statusMessage = 'Setting up...';
      });

      // Load available cameras
      _availableCameras = await availableCameras();
      print("Available cameras found: ${_availableCameras.length}");

      // Find front camera if available
      try {
        _currentCamera = _availableCameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
        _isFrontCameraActive = true;
        print("Found front camera");
      } catch (e) {
        // If no front camera, use the first available camera
        if (_availableCameras.isNotEmpty) {
          _currentCamera = _availableCameras.first;
          _isFrontCameraActive =
              _currentCamera!.lensDirection == CameraLensDirection.front;
          print(
              "No front camera found, using: ${_currentCamera!.lensDirection}");
        } else {
          throw Exception("No cameras available on this device");
        }
      }

      // Initialize the face service (loads reference image)
      final initResult = await faceService.initialize();

      // Initialize the camera with the selected camera
      await _initializeCamera();

      setState(() {
        _resultMessage = initResult;
      });
    } catch (e) {
      print("Error in system initialization: $e");
      setState(() {
        _resultMessage = 'Error initializing: $e';
        _statusMessage = 'Something went wrong';
      });
    }
  }

  @override
  void didUpdateWidget(FaceRecognitionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This ensures camera is reinitiated if needed when returning to this screen
    if (!_isCameraInitialized || _cameraController == null) {
      _initializeSystem();
    }
  }

// Also add a handler for when the screen gets focus again
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we're being displayed again
    final isVisible = ModalRoute.of(context)?.isCurrent ?? false;
    if (isVisible && (!_isCameraInitialized || _cameraController == null)) {
      // Add a small delay to allow UI to settle
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          _initializeSystem();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Safely dispose camera when app is inactive
      if (_cameraController != null && _isCameraInitialized) {
        _cameraController!.dispose();
        _isCameraInitialized = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize camera when app resumes
      if (!_isCameraInitialized || _cameraController == null) {
        _initializeCamera();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    print("FaceRecognitionScreen initialized");
    WidgetsBinding.instance.addObserver(this);

    // Initialize face service and camera with a slight delay to ensure the screen is fully rendered
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        _initializeSystem();
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      // Make sure we have a camera to use
      if (_currentCamera == null) {
        throw Exception("No camera selected");
      }

      // Dispose of the previous controller if it exists
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _isCameraInitialized = false;
      }

      // Create a new controller with the original resolution setting
      _cameraController = CameraController(
        _currentCamera!,
        ResolutionPreset.high, // Original setting
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Add a listener for camera errors
      _cameraController!.addListener(() {
        if (_cameraController!.value.hasError) {
          print("Camera error: ${_cameraController!.value.errorDescription}");
          if (mounted) {
            setState(() {
              _statusMessage =
                  'Camera error: ${_cameraController!.value.errorDescription}';
            });
          }
        }
      });

      // Wait for the controller to initialize
      await _cameraController!.initialize();

      // Set flash mode to off
      await _cameraController!.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Ready';
          _isFrontCameraActive =
              _currentCamera!.lensDirection == CameraLensDirection.front;
        });
      }
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) {
        setState(() {
          _resultMessage = 'Error initializing camera: $e';
          _statusMessage = 'Camera error';
          _isCameraInitialized = false;
        });
      }
    }
  }

  // Switch between front and back cameras
  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) {
      // Show message if there's only one camera
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other camera available')),
      );
      return;
    }

    try {
      setState(() {
        _statusMessage = 'Switching camera...';
        _isCameraInitialized = false;
      });

      // Find camera with opposite lens direction
      CameraLensDirection targetDirection = _isFrontCameraActive
          ? CameraLensDirection.back
          : CameraLensDirection.front;

      try {
        _currentCamera = _availableCameras.firstWhere(
          (camera) => camera.lensDirection == targetDirection,
        );
      } catch (e) {
        // If desired camera not found, just take the next available one
        int currentIndex = _availableCameras.indexOf(_currentCamera!);
        int nextIndex = (currentIndex + 1) % _availableCameras.length;
        _currentCamera = _availableCameras[nextIndex];
      }

      print("Switching to camera: ${_currentCamera!.lensDirection}");

      // Initialize with the new camera
      await _initializeCamera();

      // Vibrate to give feedback that camera switched
      HapticFeedback.mediumImpact();
    } catch (e) {
      print("Error switching camera: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to switch camera: $e')),
      );
      // Try to reinitialize the previous camera
      await _initializeCamera();
    }
  }

  Future<void> _takePictureAndCompare() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _resultMessage = 'Processing...';
      _statusMessage = 'Analyzing face';
      _isFaceDetected = false;
      _isRecognized = false;
    });

    try {
      if (!_isCameraInitialized || _cameraController == null) {
        await _initializeCamera();
        if (!_isCameraInitialized || _cameraController == null) {
          throw Exception('Camera not initialized');
        }
      }

      // Take picture
      final XFile capturedImage = await _cameraController!.takePicture();
      final String imagePath = capturedImage.path;

      print("Picture captured at: $imagePath");

      // Give haptic feedback
      HapticFeedback.mediumImpact();

      // Compare with reference face
      final result = await faceService.compareFaceWithReference(imagePath);

      if (result['success']) {
        setState(() {
          _isFaceDetected = true;
          _isRecognized = result['isMatch'];
          _resultMessage = result['message'];
          _statusMessage =
              result['isMatch'] ? 'Face recognized!' : 'Face not recognized';

          // Set authentication status to true when face is recognized
          if (result['isMatch']) {
            _hasFaceAuthenticated = true;
          }
        });
      } else {
        setState(() {
          _resultMessage = result['message'];
          _statusMessage = 'Detection failed';
        });
      }
    } catch (e) {
      print("Error in face comparison: $e");
      setState(() {
        _resultMessage = 'Error: $e';
        _statusMessage = 'An error occurred';
      });
    } finally {
      setState(() {
        _isProcessing = false;
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
  void dispose() {
    print("Disposing FaceRecognitionScreen");
    WidgetsBinding.instance.removeObserver(this);

    if (_cameraController != null) {
      _cameraController!.dispose();
    }

    faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent accidental back navigation
      onWillPop: () async {
        // Show confirmation dialog
        bool shouldPop = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Log out?'),
                content: const Text(
                    'Do you want to log out and return to the welcome screen?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Log Out'),
                  ),
                ],
              ),
            ) ??
            false;

        if (shouldPop) {
          await _logout();
        }
        return false;
      },
      child: Scaffold(
        // Make the scaffold transparent to let the camera fill the entire screen
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.switch_camera, color: Colors.white),
            ),
            onPressed: _switchCamera,
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  // Change color based on authentication status
                  color: _hasFaceAuthenticated ? Colors.white : Colors.grey,
                ),
              ),
              onPressed: () {
                // Check if face is authenticated before allowing profile access
                if (_hasFaceAuthenticated) {
                  // Navigate to profile screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(camera: widget.camera),
                    ),
                  );
                } else {
                  // Show message that face authentication is required
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please verify your face identity first before accessing your profile'),
                      backgroundColor: AppColors.warning,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.white),
              ),
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
        body: Stack(
          children: [
            // Camera preview as the background (full screen)
            if (_isCameraInitialized && _cameraController != null)
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),

            // Status banner at the top
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isProcessing
                            ? Icons.hourglass_top
                            : Icons.info_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Face overlay - centered circular guide
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isFaceDetected
                          ? (_isRecognized
                              ? AppColors.success
                              : AppColors.error)
                          : Colors.white.withOpacity(0.8),
                      width: _isFaceDetected ? 5 : 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: _isFaceDetected && !_isProcessing
                      ? Center(
                          child: Icon(
                            _isRecognized ? Icons.check_circle : Icons.cancel,
                            size: 80,
                            color: _isRecognized
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
            ),

            // Bottom control panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.0),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Result message
                    if (_resultMessage.isNotEmpty &&
                        _resultMessage != 'Initializing...')
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _isFaceDetected
                              ? (_isRecognized
                                  ? AppColors.success.withOpacity(0.2)
                                  : AppColors.error.withOpacity(0.2))
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isFaceDetected
                                ? (_isRecognized
                                    ? AppColors.success
                                    : AppColors.error)
                                : Colors.white.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isFaceDetected
                                  ? (_isRecognized
                                      ? Icons.check_circle
                                      : Icons.cancel)
                                  : Icons.face,
                              color: _isFaceDetected
                                  ? (_isRecognized
                                      ? AppColors.success
                                      : AppColors.error)
                                  : Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _resultMessage,
                                style: TextStyle(
                                  color: _isFaceDetected
                                      ? (_isRecognized
                                          ? AppColors.success
                                          : AppColors.error)
                                      : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: AppColors.primary.withOpacity(0.5),
                        ),
                        onPressed:
                            _isProcessing ? null : _takePictureAndCompare,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.face_retouching_natural,
                                size: 28),
                        label: Text(
                          _isProcessing ? 'Processing...' : 'Verify Face',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
