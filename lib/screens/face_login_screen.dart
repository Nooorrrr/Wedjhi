import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../services/auth_service.dart';
import '../services/face_service.dart';
import 'face_recognition_screen.dart';

class FaceLoginScreen extends StatefulWidget {
  final CameraDescription camera;
  final String email;

  const FaceLoginScreen({
    Key? key,
    required this.camera,
    required this.email,
  }) : super(key: key);

  @override
  _FaceLoginScreenState createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Position your face in the circle';
  bool _isFaceDetected = false;
  bool _isRecognized = false;

  // Track which camera is active
  CameraDescription? _currentCamera;
  List<CameraDescription> _availableCameras = [];
  bool _isFrontCameraActive = true; // Default to front camera

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSystem();
  }

  // Initialize the system
  Future<void> _initializeSystem() async {
    try {
      setState(() {
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

      // Initialize the camera
      await _initializeCamera();

      setState(() {
        _statusMessage = 'Look at the camera';
      });
    } catch (e) {
      print("Error in system initialization: $e");
      setState(() {
        _statusMessage = 'Error initializing: $e';
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

      // Create a new controller
      _cameraController = CameraController(
        _currentCamera!,
        ResolutionPreset.high,
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
          _isFrontCameraActive =
              _currentCamera!.lensDirection == CameraLensDirection.front;
        });
      }
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) {
        setState(() {
          _statusMessage = 'Error initializing camera: $e';
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

  Future<void> _verifyFace() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Verifying...';
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

      // Initialize face service with user's reference face from Firestore
      await authService.signIn(
          widget.email, ''); // Attempt sign in without password to load user
      final initResult = await faceService.initialize();

      if (!initResult.contains('Ready for face verification')) {
        setState(() {
          _isProcessing = false;
          _statusMessage = initResult;
        });
        return;
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
          _statusMessage = result['message'];
        });

        if (result['isMatch']) {
          // Successful face recognition - wait a moment to show the success state
          await Future.delayed(const Duration(milliseconds: 1000));

          if (!mounted) return;

          // Navigate to home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FaceRecognitionScreen(camera: widget.camera),
            ),
            (route) => false,
          );
        } else {
          // Failed recognition
          setState(() {
            _statusMessage =
                'Face not recognized. Please try again or use password.';
          });
        }
      } else {
        setState(() {
          _statusMessage = result['message'];
        });
      }
    } catch (e) {
      print("Error in face verification: $e");
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_cameraController != null) {
      _cameraController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Face Login: ${widget.email}'),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
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
        ],
      ),
      body: Stack(
        children: [
          // Camera preview as the background
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
                child: CircularProgressIndicator(color: Colors.white),
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
                          : (_isFaceDetected
                              ? (_isRecognized
                                  ? Icons.check_circle
                                  : Icons.cancel)
                              : Icons.face),
                      color: _isFaceDetected
                          ? (_isRecognized
                              ? AppColors.success
                              : AppColors.error)
                          : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _isFaceDetected
                              ? (_isRecognized
                                  ? AppColors.success
                                  : AppColors.error)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
                        ? (_isRecognized ? AppColors.success : AppColors.error)
                        : Colors.white.withOpacity(0.8),
                    width: _isFaceDetected ? 5 : 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: _isFaceDetected
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

          // Bottom controls
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
                      onPressed: _isProcessing ? null : _verifyFace,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.face_retouching_natural, size: 28),
                      label: Text(
                        _isProcessing ? 'Verifying...' : 'Verify Face',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Login'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
