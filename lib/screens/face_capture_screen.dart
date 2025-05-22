import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/constants.dart';
import '../widgets/app_button.dart';
import '../services/face_service.dart';

class FaceCaptureScreen extends StatefulWidget {
  final CameraDescription camera;
  final String email;
  final String password;

  const FaceCaptureScreen({
    Key? key,
    required this.camera,
    required this.email,
    required this.password,
  }) : super(key: key);

  @override
  _FaceCaptureScreenState createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Please take a clear photo of your face';
  bool _isFaceDetected = false;
  bool _hasImage = false;
  XFile? _capturedImage;
  String? _base64Image;

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
        _statusMessage = 'Setting up camera...';
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

      // Initialize the camera with the selected camera
      await _initializeCamera();

      setState(() {
        _statusMessage = 'Position your face in the circle';
      });
    } catch (e) {
      print("Error in system initialization: $e");
      setState(() {
        _statusMessage = 'Error initializing camera: $e';
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

  Future<void> _takePicture() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing...';
      _isFaceDetected = false;
      _hasImage = false;
      _base64Image = null;
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

      // Process the image to detect face
      final result = await faceService.processImageForReference(imagePath);

      if (result['success']) {
        setState(() {
          _capturedImage = capturedImage;
          _isFaceDetected = true;
          _hasImage = true;
          _statusMessage = 'Face detected! Tap Continue to proceed.';
          _base64Image = result['base64Image'];
        });
      } else {
        setState(() {
          _capturedImage = capturedImage;
          _hasImage = true;
          _isFaceDetected = false;
          _statusMessage = result['message'];
        });
      }
    } catch (e) {
      print("Error capturing image: $e");
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
      _isFaceDetected = false;
      _hasImage = false;
      _base64Image = null;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 80,
      );

      if (pickedImage == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No image selected';
        });
        return;
      }

      print("Image picked from gallery: ${pickedImage.path}");

      // Process the image to detect face
      final result =
          await faceService.processImageForReference(pickedImage.path);

      if (result['success']) {
        setState(() {
          _capturedImage = pickedImage;
          _isFaceDetected = true;
          _hasImage = true;
          _statusMessage = 'Face detected! Tap Continue to proceed.';
          _base64Image = result['base64Image'];
        });
      } else {
        setState(() {
          _capturedImage = pickedImage;
          _hasImage = true;
          _isFaceDetected = false;
          _statusMessage = result['message'];
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _continueToNextScreen() {
    if (!_isFaceDetected || _base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a photo with a clearly visible face.'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'success': true,
      'base64Image': _base64Image,
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_cameraController != null) {
      _cameraController!.dispose();
    }
    super.dispose();
  }

  // Helper method to handle tap based on processing state
  void _handleTakePicture() {
    if (!_isProcessing) {
      _takePicture();
    }
  }

  // Helper method to handle gallery selection based on processing state
  void _handlePickImage() {
    if (!_isProcessing) {
      _pickImageFromGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Capture Face'),
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
            onPressed: _hasImage ? null : _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content: Camera preview or captured image
          if (_hasImage && _capturedImage != null)
            // Show captured image
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Image.file(File(_capturedImage!.path)),
              ),
            )
          else if (_isCameraInitialized && _cameraController != null)
            // Show camera preview
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
            // Loading state
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
                              ? Icons.check_circle
                              : Icons.info_outline),
                      color: _isFaceDetected ? AppColors.success : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _isFaceDetected
                              ? AppColors.success
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
          if (!_hasImage)
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
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
                  // Action buttons
                  if (_hasImage)
                    // Show retake and continue buttons when image is captured
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlinedButton(
                            text: 'Retake',
                            icon: Icons.refresh,
                            onPressed: () {
                              setState(() {
                                _hasImage = false;
                                _capturedImage = null;
                                _isFaceDetected = false;
                                _base64Image = null;
                                _statusMessage =
                                    'Position your face in the circle';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppButton(
                            text: 'Continue',
                            icon: Icons.check,
                            onPressed:
                                _isFaceDetected ? _continueToNextScreen : () {},
                            isLoading: _isProcessing,
                          ),
                        ),
                      ],
                    )
                  else
                    // Show capture button when camera is active
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery button
                        GestureDetector(
                          onTap: _handlePickImage,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.photo,
                              color: _isProcessing ? Colors.grey : Colors.white,
                              size: 30,
                            ),
                          ),
                        ),

                        // Capture button
                        GestureDetector(
                          onTap: _handleTakePicture,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _isProcessing
                                  ? Colors.grey.withOpacity(0.5)
                                  : AppColors.primary.withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                          ),
                        ),

                        // Empty container for layout balance
                        Container(width: 60, height: 60),
                      ],
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
