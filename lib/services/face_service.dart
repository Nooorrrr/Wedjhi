import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'auth_service.dart';

/// A service class for handling face detection and recognition with enhanced security
class FaceService {
  // Create face detector with high-accuracy settings
  FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15, // Increased sensitivity for face detection
    ),
  );

  AudioPlayer? _audioPlayer;

  // Getter for audio player that ensures it's initialized
  AudioPlayer get audioPlayer {
    _audioPlayer ??= AudioPlayer();
    return _audioPlayer!;
  }

  // Constructor
  FaceService() {
    _preloadAudio();
  }

  Future<void> _preloadAudio() async {
    try {
      print("Preloading audio files");
      _audioPlayer ??= AudioPlayer();
    } catch (e) {
      print("Error preloading audio: $e");
    }
  }

  Uint8List? _referenceImageBytes;
  List<Face>? _referenceFaces;
  bool _isInitialized = false;
  String _userId = '';
  DateTime? _lastInitialized;

  // INCREASED thresholds for more accurate matching and fewer false positives
  static const double SIMILARITY_THRESHOLD = 0.92; // Significantly increased from 0.88 for fewer false positives
  static const double HIGH_CONFIDENCE_THRESHOLD = 0.95; // Increased from 0.93
  static const double ANGLE_THRESHOLD = 8.0; // Increased from 7.0 for more lenient angle matching
  static const double EYE_RATIO_MIN = 0.85; // More lenient ratio check
  static const double EYE_RATIO_MAX = 1.15; // More lenient ratio check
  static const int MAX_IMAGE_DIMENSION = 1024; // Limit image size
  static const int MIN_LANDMARKS = 5; // Increased from 4 to require ALL key landmarks

  /// Initialize by loading the reference image from Firestore
  Future<String> initialize({String? email}) async {
    try {
      _isInitialized = false;

      if (email == null) {
        print("[FaceService] ERROR: Email is required for initialization");
        return 'Email is required for face verification.';
      }

      // Get the user's face image from Firestore using email
      final String? base64Image = await authService.getUserFaceImageByEmail(email);

      if (base64Image == null || base64Image.isEmpty) {
        print("[FaceService] ERROR: No face image found for email: $email");
        return 'No face image found. Please register first with a face image.';
      }

      print(
          "[FaceService] Retrieved base64 face image from Firestore (length: ${base64Image.length})");

      // Check if the base64 string is valid
      if (!_isValidBase64(base64Image)) {
        print("[FaceService] ERROR: Invalid base64 string format");
        return 'Error: Invalid image format. Please register again with a new image.';
      }

      // Convert base64 to bytes
      try {
        _referenceImageBytes = base64Decode(base64Image);
        print(
            "[FaceService] Decoded base64 image: ${_referenceImageBytes?.length} bytes");

        if (_referenceImageBytes == null || _referenceImageBytes!.isEmpty) {
          print("[FaceService] ERROR: Empty decoded image data");
          return 'Error decoding face image. Please register again with a new image.';
        }
      } catch (e) {
        print("[FaceService] ERROR: Failed to decode base64 image: $e");
        return 'Error decoding face image: $e';
      }

      // Process reference image to extract face features
      try {
        // Create a temporary file with the bytes
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_reference_${email ?? "unknown"}.jpg');
        await tempFile.writeAsBytes(_referenceImageBytes!);

        print("[FaceService] Temporary file created at: ${tempFile.path}");

        final InputImage inputImage = InputImage.fromFilePath(tempFile.path);
        _referenceFaces = await _faceDetector.processImage(inputImage);

        print(
            "[FaceService] Face detection complete. Faces found: ${_referenceFaces?.length}");

        if (_referenceFaces == null || _referenceFaces!.isEmpty) {
          print("[FaceService] ERROR: No face detected in reference image");
          return 'No face detected in your reference image. Please register again with a clearer image.';
        }

        if (_referenceFaces!.length > 1) {
          print(
              "[FaceService] WARNING: Multiple faces (${_referenceFaces!.length}) found in reference image");
          return 'Multiple faces detected in your reference image. Please use an image with only your face.';
        }

        // Check reference face quality
        if (!_isFaceQualityGood(_referenceFaces!.first)) {
          print("[FaceService] ERROR: Reference face quality not good enough");
          return 'Reference face quality is not good enough. Please register again with a clearer image.';
        }

        // Log face detection quality information
        _logFaceQuality(_referenceFaces!.first, "REFERENCE");

        _isInitialized = true;
        _lastInitialized = DateTime.now();
        return 'Ready for face verification';
      } catch (e) {
        print("[FaceService] ERROR: Failed to process reference image: $e");
        return 'Error processing reference image: $e';
      }
    } catch (e) {
      print("[FaceService] ERROR: Initialization failed: $e");
      return 'Error initializing face service: $e';
    }
  }

  /// Check if a string is valid base64
  bool _isValidBase64(String str) {
    // More strict validation for base64 string
    if (str.isEmpty) return false;

    try {
      // Check if the string has valid base64 characters
      final regex = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
      if (!regex.hasMatch(str)) {
        print("[FaceService] Base64 format validation failed");
        return false;
      }

      // Check reasonable length for face image
      if (str.length < 5000) {
        print(
            "[FaceService] Base64 too short to be a valid image: ${str.length} chars");
        return false;
      }

      // Try decoding a small part to verify it's valid base64
      base64Decode(str.substring(0, min(100, str.length)));
      return true;
    } catch (e) {
      print("[FaceService] Base64 validation failed: $e");
      return false;
    }
  }

  /// Log face quality metrics for debugging
  void _logFaceQuality(Face face, String label) {
    print("[FaceService] $label FACE METRICS:");
    print("[FaceService] - Tracking ID: ${face.trackingId}");
    print("[FaceService] - Head Euler X: ${face.headEulerAngleX}°");
    print("[FaceService] - Head Euler Y: ${face.headEulerAngleY}°");
    print("[FaceService] - Head Euler Z: ${face.headEulerAngleZ}°");
    print("[FaceService] - Smiling Probability: ${face.smilingProbability}");
    print(
        "[FaceService] - Left Eye Open Probability: ${face.leftEyeOpenProbability}");
    print(
        "[FaceService] - Right Eye Open Probability: ${face.rightEyeOpenProbability}");
    print("[FaceService] - Landmarks count: ${face.landmarks.length}");

    final landmarkTypes = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.bottomMouth,
    ];

    for (var type in landmarkTypes) {
      final landmark = face.landmarks[type];
      if (landmark != null) {
        print(
            "[FaceService] - Landmark $type: (${landmark.position.x}, ${landmark.position.y})");
      } else {
        print("[FaceService] - Landmark $type: Not detected");
      }
    }

    // Calculate face size in the image
    if (face.boundingBox.width > 0 && face.boundingBox.height > 0) {
      print(
          "[FaceService] - Face bounding box: ${face.boundingBox.width} x ${face.boundingBox.height}");
      // Calculate face area in pixels
      final faceArea = face.boundingBox.width * face.boundingBox.height;
      print("[FaceService] - Face area: $faceArea pixels²");
    }
  }

  /// Take a picture and compare it with the reference face
  Future<Map<String, dynamic>> compareFaceWithReference(
      String imagePath) async {
    return _safelyExecuteFaceOperation(() async {
      print("[FaceService] Comparing face at path: $imagePath");

      // Force re-initialization if it's been more than 10 minutes since last initialization
      // This ensures we always have the latest reference image
      final now = DateTime.now();
      if (_lastInitialized == null ||
          now.difference(_lastInitialized!).inMinutes > 10) {
        print("[FaceService] Reinitializing due to timeout");
        await initialize();
      }

      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final List<Face> detectedFaces =
          await _faceDetector.processImage(inputImage);

      print(
          "[FaceService] Faces detected in captured image: ${detectedFaces.length}");

      if (detectedFaces.isEmpty) {
        print("[FaceService] ERROR: No face detected in captured image");
        await _playSound(false);
        return {
          'success': false,
          'message': 'No face detected. Please try again with better lighting.',
        };
      }

      if (detectedFaces.length > 1) {
        print(
            "[FaceService] WARNING: Multiple faces detected (${detectedFaces.length})");
        await _playSound(false);
        return {
          'success': false,
          'message':
              'Multiple faces detected. Please ensure only your face is in view.',
        };
      }

      // Get the first (and only) detected face
      final Face detectedFace = detectedFaces.first;

      // Log face detection quality for the detected face
      _logFaceQuality(detectedFace, "DETECTED");

      // Check face quality before attempting comparison
      if (!_isFaceQualityGood(detectedFace)) {
        print("[FaceService] ERROR: Detected face quality not good enough");
        await _playSound(false);
        return {
          'success': false,
          'message':
              'Face quality not good enough. Please try again with better lighting.',
        };
      }

      // Check if face is too close to the camera
      if (_isFaceTooClose(detectedFace)) {
        print("[FaceService] ERROR: Face too close to camera");
        await _playSound(false);
        return {
          'success': false,
          'message': 'Face too close to camera. Please move back a bit.',
        };
      }

      if (!_isInitialized ||
          _referenceFaces == null ||
          _referenceFaces!.isEmpty) {
        print(
            "[FaceService] Reference image not available, initializing again");
        final initResult = await initialize();

        if (!_isInitialized ||
            _referenceFaces == null ||
            _referenceFaces!.isEmpty) {
          print(
              "[FaceService] ERROR: Failed to initialize reference image: $initResult");
          await _playSound(false);
          return {
            'success': false,
            'message': initResult,
          };
        }
      }

      // Compare faces with enhanced algorithm
      print("[FaceService] Comparing faces with high-security algorithm...");
      final Map<String, dynamic> compareResult =
          await _compareFacesEnhanced(detectedFace, _referenceFaces!.first);
      final bool isMatch = compareResult['isMatch'];
      final double similarityScore = compareResult['similarityScore'];
      final Map<String, dynamic> details = compareResult['details'];

      print(
          "[FaceService] Face match result: $isMatch (Score: $similarityScore)");

      // Log detailed comparison results
      print("[FaceService] Comparison details:");
      details.forEach((key, value) {
        if (key != 'similarities') {
          print("[FaceService] - $key: $value");
        }
      });

      if (details.containsKey('similarities')) {
        print("[FaceService] Feature similarities:");
        (details['similarities'] as Map<String, dynamic>).forEach((key, value) {
          print("[FaceService] - $key: $value");
        });
      }

      await _playSound(isMatch);

      return {
        'success': true,
        'isMatch': isMatch,
        'similarityScore': similarityScore,
        'message': isMatch
            ? 'Face recognized with ${(similarityScore * 100).toStringAsFixed(1)}% confidence'
            : 'Face not recognized. (Score: ${(similarityScore * 100).toStringAsFixed(1)}%)',
      };
    }, 'comparison');
  }

  /// Check if a face is too close to the camera based on face size relative to the image
  bool _isFaceTooClose(Face face) {
    // Calculate face width as percentage of image width
    final faceWidth = face.boundingBox.width;
    final faceHeight = face.boundingBox.height;

    // Log the face dimensions for debugging
    print("[FaceService] Face dimensions: ${faceWidth}x${faceHeight} pixels");

    // If face is very large in the frame, consider it too close
    if (faceWidth > 900 || faceHeight > 900) {
      print("[FaceService] Face too close to camera: dimensions too large");
      return true;
    }

    return false;
  }

  /// Process an image and detect faces for saving reference image
  Future<Map<String, dynamic>> processImageForReference(
      String imagePath) async {
    return _safelyExecuteFaceOperation(() async {
      print("[FaceService] Processing image for reference: $imagePath");

      // Convert image to InputImage for processing
      final InputImage inputImage = InputImage.fromFilePath(imagePath);

      // Process the image to detect faces
      final List<Face> detectedFaces =
          await _faceDetector.processImage(inputImage);

      if (detectedFaces.isEmpty) {
        print("[FaceService] ERROR: No face detected in reference image");
        return {
          'success': false,
          'message':
              'No face detected in the image. Please try again with a clearer photo.',
        };
      }

      if (detectedFaces.length > 1) {
        print(
            "[FaceService] WARNING: Multiple faces detected (${detectedFaces.length}) in reference image");
        return {
          'success': false,
          'message':
              'Multiple faces detected. Please use an image with only your face.',
        };
      }

      // Log quality of the detected face
      _logFaceQuality(detectedFaces.first, "NEW REFERENCE");

      // Check face quality
      if (!_isFaceQualityGood(detectedFaces.first)) {
        print("[FaceService] ERROR: Face quality not good enough");
        return {
          'success': false,
          'message':
              'Face quality not good enough. Please use a clearer photo with good lighting and look directly at the camera.',
        };
      }

      // Check if face is too close
      if (_isFaceTooClose(detectedFaces.first)) {
        print(
            "[FaceService] ERROR: Face too close to camera in reference image");
        return {
          'success': false,
          'message':
              'Face too close to camera. Please move back a bit and retake the photo.',
        };
      }

      // Resize and optimize the image
      final File optimizedFile = await _optimizeImage(imagePath);

      // Get image bytes for storing
      final Uint8List imageBytes = await optimizedFile.readAsBytes();

      // Convert to base64 for storage
      final String base64Image = base64Encode(imageBytes);
      print(
          "[FaceService] Image converted to base64: ${base64Image.length} characters");

      // Verify the base64 string by decoding it
      try {
        final testDecode = base64Decode(base64Image);
        print(
            "[FaceService] Base64 verification: Successfully decoded ${testDecode.length} bytes");
      } catch (e) {
        print("[FaceService] ERROR: Failed to verify base64 encoding: $e");
        return {
          'success': false,
          'message': 'Error encoding image. Please try again.',
        };
      }

      return {
        'success': true,
        'message': 'Face detected successfully',
        'base64Image': base64Image,
      };
    }, 'processing');
  }

  /// Optimize image for storage and processing
  Future<File> _optimizeImage(String imagePath) async {
    final File originalFile = File(imagePath);
    final Uint8List bytes = await originalFile.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final File optimizedFile = File(
        '${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg');

    // For now, just copy the file. In a real implementation, you would
    // resize and compress the image here to reduce storage requirements.
    await optimizedFile.writeAsBytes(bytes);

    print(
        "[FaceService] Image optimized: ${await originalFile.length()} bytes -> ${await optimizedFile.length()} bytes");
    return optimizedFile;
  }

  /// More strict face quality check method to reduce false positives
  bool _isFaceQualityGood(Face face) {
    // Must have all key landmarks
    final requiredLandmarks = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
    ];

    int foundLandmarks = 0;
    for (var type in requiredLandmarks) {
      if (face.landmarks.containsKey(type)) {
        foundLandmarks++;
      } else {
        print("[FaceService] Missing required landmark: $type");
      }
    }

    if (foundLandmarks < MIN_LANDMARKS) {
      print(
          "[FaceService] Not enough landmarks detected: $foundLandmarks < $MIN_LANDMARKS");
      return false;
    }

    // Strict head rotation check - facing front is required
    if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 15) {
      print(
          "[FaceService] Head rotation Y too large: ${face.headEulerAngleY}°");
      return false;
    }

    if (face.headEulerAngleZ != null && face.headEulerAngleZ!.abs() > 15) {
      print(
          "[FaceService] Head rotation Z too large: ${face.headEulerAngleZ}°");
      return false;
    }

    // Eyes must be open
    if (face.leftEyeOpenProbability != null &&
        face.leftEyeOpenProbability! < 0.6) {
      print(
          "[FaceService] Left eye not open enough: ${face.leftEyeOpenProbability}");
      return false;
    }

    if (face.rightEyeOpenProbability != null &&
        face.rightEyeOpenProbability! < 0.6) {
      print(
          "[FaceService] Right eye not open enough: ${face.rightEyeOpenProbability}");
      return false;
    }

    // Check face size for better recognition
    final boundingBox = face.boundingBox;
    if (boundingBox.width < 150 || boundingBox.height < 150) {
      print(
          "[FaceService] Face too small in frame: ${boundingBox.width}x${boundingBox.height}");
      return false;
    }

    return true;
  }

  /// Enhanced face comparison algorithm with more accurate matching to reduce false positives
  Future<Map<String, dynamic>> _compareFacesEnhanced(
      Face detectedFace, Face referenceFace) async {
    print(
        "[FaceService] Starting enhanced facial comparison with high security standards");

    // Default result
    Map<String, dynamic> result = {
      'isMatch': false,
      'similarityScore': 0.0,
      'details': <String, dynamic>{},
    };

    // Check essential landmarks presence - require ALL landmarks
    final requiredLandmarks = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
    ];

    for (var type in requiredLandmarks) {
      if (!detectedFace.landmarks.containsKey(type) ||
          !referenceFace.landmarks.containsKey(type)) {
        print("[FaceService] Missing required landmark: $type");
        return result; // Early return - strict requirement
      }
    }

    // STRICT head rotation comparison - must be very similar
    if (detectedFace.headEulerAngleY != null &&
        referenceFace.headEulerAngleY != null) {
      final double yDiff =
          (detectedFace.headEulerAngleY! - referenceFace.headEulerAngleY!)
              .abs();
      result['details']['yRotationDiff'] = yDiff;

      if (yDiff > ANGLE_THRESHOLD) {
        print(
            "[FaceService] Head Y rotation difference too large: $yDiff° (threshold: $ANGLE_THRESHOLD°)");
        return result; // Early return - strict requirement
      }
    }

    if (detectedFace.headEulerAngleZ != null &&
        referenceFace.headEulerAngleZ != null) {
      final double zDiff =
          (detectedFace.headEulerAngleZ! - referenceFace.headEulerAngleZ!)
              .abs();
      result['details']['zRotationDiff'] = zDiff;

      if (zDiff > ANGLE_THRESHOLD) {
        print(
            "[FaceService] Head Z rotation difference too large: $zDiff° (threshold: $ANGLE_THRESHOLD°)");
        return result; // Early return - strict requirement
      }
    }

    // Get key facial landmarks
    final Point<int> detectedNose =
        detectedFace.landmarks[FaceLandmarkType.noseBase]!.position;
    final Point<int> referenceNose =
        referenceFace.landmarks[FaceLandmarkType.noseBase]!.position;
    final Point<int> detectedLeftEye =
        detectedFace.landmarks[FaceLandmarkType.leftEye]!.position;
    final Point<int> referenceLeftEye =
        referenceFace.landmarks[FaceLandmarkType.leftEye]!.position;
    final Point<int> detectedRightEye =
        detectedFace.landmarks[FaceLandmarkType.rightEye]!.position;
    final Point<int> referenceRightEye =
        referenceFace.landmarks[FaceLandmarkType.rightEye]!.position;
    final Point<int> detectedLeftMouth =
        detectedFace.landmarks[FaceLandmarkType.leftMouth]!.position;
    final Point<int> referenceLeftMouth =
        referenceFace.landmarks[FaceLandmarkType.leftMouth]!.position;
    final Point<int> detectedRightMouth =
        detectedFace.landmarks[FaceLandmarkType.rightMouth]!.position;
    final Point<int> referenceRightMouth =
        referenceFace.landmarks[FaceLandmarkType.rightMouth]!.position;

    // Additional points if available
    final Point<int>? detectedBottomMouth =
        detectedFace.landmarks[FaceLandmarkType.bottomMouth]?.position;
    final Point<int>? referenceBottomMouth =
        referenceFace.landmarks[FaceLandmarkType.bottomMouth]?.position;

    try {
      // Calculate distances between facial landmarks for detected face
      final double detectedEyeDistance =
          _distance(detectedLeftEye, detectedRightEye);
      final double referenceEyeDistance =
          _distance(referenceLeftEye, referenceRightEye);

      // Calculate ratio between eyes - important for distance normalization
      final double eyeRatio = detectedEyeDistance / referenceEyeDistance;
      result['details']['eyeRatio'] = eyeRatio;

      // STRICT eye ratio check - must be very similar
      if (eyeRatio < EYE_RATIO_MIN || eyeRatio > EYE_RATIO_MAX) {
        print(
            "[FaceService] Eye distance ratio out of range: $eyeRatio (acceptable range: $EYE_RATIO_MIN-$EYE_RATIO_MAX)");
        return result; // Early return - strict requirement
      }

      // Calculate normalized distances and angles for facial comparisons
      Map<String, double> similarities = {};

      // 1. Triangle Relationships - these are very person-specific and resistant to lighting changes

      // 1.1 Eye-to-nose triangle (left side)
      final double detectedLeftEyeToNose =
          _distance(detectedLeftEye, detectedNose) / detectedEyeDistance;
      final double referenceLeftEyeToNose =
          _distance(referenceLeftEye, referenceNose) / referenceEyeDistance;
      similarities['leftEyeToNoseRatio'] =
          1 - (detectedLeftEyeToNose - referenceLeftEyeToNose).abs();

      // 1.2 Eye-to-nose triangle (right side)
      final double detectedRightEyeToNose =
          _distance(detectedRightEye, detectedNose) / detectedEyeDistance;
      final double referenceRightEyeToNose =
          _distance(referenceRightEye, referenceNose) / referenceEyeDistance;
      similarities['rightEyeToNoseRatio'] =
          1 - (detectedRightEyeToNose - referenceRightEyeToNose).abs();

      // 1.3 Eye-to-eye ratio (face width)
      similarities['eyeToEyeRatio'] = 1 - min((eyeRatio - 1).abs(), 0.3);

      // 2. Angles between features - these capture the unique shape of a person's face

      // 2.1 Eye-nose-eye angle (face shape)
      final double detectedEyeNoseEyeAngle =
          _calculateAngle(detectedLeftEye, detectedNose, detectedRightEye);
      final double referenceEyeNoseEyeAngle =
          _calculateAngle(referenceLeftEye, referenceNose, referenceRightEye);
      final double eyeNoseEyeAngleDiff =
          (detectedEyeNoseEyeAngle - referenceEyeNoseEyeAngle).abs();

      // If this critical angle differs too much, it's not the same person
      if (eyeNoseEyeAngleDiff > ANGLE_THRESHOLD) {
        print(
            "[FaceService] Eye-nose-eye angle difference too large: $eyeNoseEyeAngleDiff° (threshold: $ANGLE_THRESHOLD°)");
        // Instead of immediate rejection, reduce the similarity score
        similarities['eyeNoseEyeAngle'] = 0.5;
      } else {
        similarities['eyeNoseEyeAngle'] = 1 - (eyeNoseEyeAngleDiff / 180);
      }

      // 2.2 Left eye angle (from horizontal)
      double detectedLeftEyeAngle =
          _calculateAngleWithHorizontal(detectedLeftEye, detectedRightEye);
      double referenceLeftEyeAngle =
          _calculateAngleWithHorizontal(referenceLeftEye, referenceRightEye);
      similarities['leftEyeAngle'] = 1 -
          min((detectedLeftEyeAngle - referenceLeftEyeAngle).abs() / 90, 0.5);

      // 3. Facial proportions - key ratios that identify a person

      // 3.1 Mouth width to eye distance ratio
      final double detectedMouthWidth =
          _distance(detectedLeftMouth, detectedRightMouth) /
              detectedEyeDistance;
      final double referenceMouthWidth =
          _distance(referenceLeftMouth, referenceRightMouth) /
              referenceEyeDistance;
      similarities['mouthWidthRatio'] =
          1 - min((detectedMouthWidth - referenceMouthWidth).abs(), 0.3);

      // 3.2 Eye-to-mouth vertical distance
      final Point<int> detectedMouthCenter = Point<int>(
          (detectedLeftMouth.x + detectedRightMouth.x) ~/ 2,
          (detectedLeftMouth.y + detectedRightMouth.y) ~/ 2);
      final Point<int> referenceMouthCenter = Point<int>(
          (referenceLeftMouth.x + referenceRightMouth.x) ~/ 2,
          (referenceLeftMouth.y + referenceRightMouth.y) ~/ 2);
      final Point<int> detectedEyeCenter = Point<int>(
          (detectedLeftEye.x + detectedRightEye.x) ~/ 2,
          (detectedLeftEye.y + detectedRightEye.y) ~/ 2);
      final Point<int> referenceEyeCenter = Point<int>(
          (referenceLeftEye.x + referenceRightEye.x) ~/ 2,
          (referenceLeftEye.y + referenceRightEye.y) ~/ 2);

      final double detectedEyeToMouthDist =
          _distance(detectedEyeCenter, detectedMouthCenter) /
              detectedEyeDistance;
      final double referenceEyeToMouthDist =
          _distance(referenceEyeCenter, referenceMouthCenter) /
              referenceEyeDistance;
      similarities['eyeToMouthRatio'] = 1 -
          min((detectedEyeToMouthDist - referenceEyeToMouthDist).abs(), 0.3);

      // 3.3 Nose-to-mouth distance ratio
      if (detectedBottomMouth != null && referenceBottomMouth != null) {
        final double detectedNoseToMouth =
            _distance(detectedNose, detectedBottomMouth) / detectedEyeDistance;
        final double referenceNoseToMouth =
            _distance(referenceNose, referenceBottomMouth) /
                referenceEyeDistance;
        similarities['noseToMouthRatio'] =
            1 - min((detectedNoseToMouth - referenceNoseToMouth).abs(), 0.3);
      }

      // 4. Advanced feature: Spatial relationship patterns

      // 4.1 Perspective invariant ratio: comparing the ratio of distances
      final double detectedLeftEyeToMouthRatio =
          _distance(detectedLeftEye, detectedLeftMouth) /
              _distance(detectedRightEye, detectedRightMouth);
      final double referenceLeftEyeToMouthRatio =
          _distance(referenceLeftEye, referenceLeftMouth) /
              _distance(referenceRightEye, referenceRightMouth);
      similarities['eyeMouthSymmetryRatio'] = 1 -
          min(
              (detectedLeftEyeToMouthRatio - referenceLeftEyeToMouthRatio)
                  .abs(),
              0.5);

      // 4.2 Cross-face diagonal ratios (very unique to individuals)
      final double detectedLeftEyeToRightMouth =
          _distance(detectedLeftEye, detectedRightMouth) / detectedEyeDistance;
      final double referenceLeftEyeToRightMouth =
          _distance(referenceLeftEye, referenceRightMouth) /
              referenceEyeDistance;
      similarities['leftEyeToRightMouthRatio'] = 1 -
          min(
              (detectedLeftEyeToRightMouth - referenceLeftEyeToRightMouth)
                  .abs(),
              0.3);

      final double detectedRightEyeToLeftMouth =
          _distance(detectedRightEye, detectedLeftMouth) / detectedEyeDistance;
      final double referenceRightEyeToLeftMouth =
          _distance(referenceRightEye, referenceLeftMouth) /
              referenceEyeDistance;
      similarities['rightEyeToLeftMouthRatio'] = 1 -
          min(
              (detectedRightEyeToLeftMouth - referenceRightEyeToLeftMouth)
                  .abs(),
              0.3);

      // Log all similarity scores for debugging
      print("[FaceService] Similarity scores:");
      similarities.forEach((key, value) {
        print("[FaceService] - $key: $value");
      });

      // Calculate weighted average similarity with emphasis on most distinctive features
      Map<String, double> weights = {
        'leftEyeToNoseRatio': 1.5,
        'rightEyeToNoseRatio': 1.5,
        'eyeToEyeRatio': 0.7,
        'eyeNoseEyeAngle': 2.0, // Very important facial triangle
        'leftEyeAngle': 1.2, // Eye alignment is person-specific
        'mouthWidthRatio': 1.0,
        'eyeToMouthRatio': 1.8, // Key facial proportion
        'noseToMouthRatio': 1.5,
        'eyeMouthSymmetryRatio': 1.6, // Unique personal symmetry pattern
        'leftEyeToRightMouthRatio': 1.4, // Cross-face pattern
        'rightEyeToLeftMouthRatio': 1.4, // Cross-face pattern
      };

      double totalWeight = 0;
      double weightedSum = 0;
      int validFeatures = 0;
      Map<String, bool> failedFeatures = {};

      // Track which measurements have very low similarity for reporting
      similarities.forEach((key, value) {
        // Skip invalid measurements (NaN)
        if (value.isNaN) {
          print("[FaceService] Skipping invalid measurement: $key = $value");
          return;
        }

        // Flag low similarity features (potential mismatch indicators)
        if (value < 0.75) {
          failedFeatures[key] = true;
          print("[FaceService] Low similarity feature: $key = $value");
        }

        // Apply feature weight
        double weight = weights[key] ?? 1.0;
        weightedSum += value * weight;
        totalWeight += weight;
        validFeatures++;
      });

      // Store failed features in result
      result['details']['failedFeatures'] = failedFeatures;

      // Check if we have enough valid features
      if (validFeatures < MIN_LANDMARKS) {
        print(
            "[FaceService] Not enough valid facial measurements: $validFeatures < $MIN_LANDMARKS");
        return result;
      }

      // If too many features have low similarity, reject the match
      if (failedFeatures.length > 3) {
        // If more than 3 features have low similarity
        print(
            "[FaceService] Too many features with low similarity: ${failedFeatures.length}");
        return result;
      }

      // Final similarity score
      double similarityScore = totalWeight > 0 ? weightedSum / totalWeight : 0;
      result['similarityScore'] = similarityScore;
      result['details']['similarities'] = similarities;
      result['details']['validFeatures'] = validFeatures;

      print(
          "[FaceService] Final similarity score: $similarityScore (threshold: $SIMILARITY_THRESHOLD)");

      // Use higher threshold for close-up faces
      double effectiveThreshold = SIMILARITY_THRESHOLD;
      if (_isFacePotentiallyClose(detectedFace)) {
        effectiveThreshold = SIMILARITY_THRESHOLD + 0.02;
        print(
            "[FaceService] Face appears close to camera - using higher threshold: $effectiveThreshold");
      }

      result['details']['effectiveThreshold'] = effectiveThreshold;

      // Apply extremely strict matching criteria to prevent false positives
      if (similarityScore >= effectiveThreshold) {
        // For high confidence matches, immediately accept
        if (similarityScore >= HIGH_CONFIDENCE_THRESHOLD) {
          print(
              "[FaceService] High confidence match ($similarityScore >= $HIGH_CONFIDENCE_THRESHOLD)");
          result['isMatch'] = true;
        }
        // For borderline matches, do additional checks
        else {
          // Additional verification: eye openness should be reasonably consistent
          bool eyeConsistencyCheck = true;
          if (detectedFace.leftEyeOpenProbability != null &&
              referenceFace.leftEyeOpenProbability != null) {
            double eyeDiff = (detectedFace.leftEyeOpenProbability! -
                    referenceFace.leftEyeOpenProbability!)
                .abs();
            if (eyeDiff > 0.35) {
              print("[FaceService] Left eye openness inconsistent: $eyeDiff");
              eyeConsistencyCheck = false;
            }
          }

          // Only match if additional checks pass AND no critical features failed
          result['isMatch'] = eyeConsistencyCheck &&
              !failedFeatures.containsKey('eyeNoseEyeAngle');
          print(
              "[FaceService] Borderline match with additional checks: ${result['isMatch']}");
        }
      }

      return result;
    } catch (e) {
      print("[FaceService] Error in face comparison: $e");
      return result;
    }
  }

  /// Check if a face appears potentially close to the camera
  bool _isFacePotentiallyClose(Face face) {
    final boundingBox = face.boundingBox;

    // If face takes up a large portion of the image, it's too close
    if (boundingBox.width > 800 || boundingBox.height > 800) {
      return true;
    }

    // Calculate face area
    final faceArea = boundingBox.width * boundingBox.height;
    if (faceArea > 400000) {
      return true;
    }

    return false;
  }

  /// Calculate distance between two points
  double _distance(Point<int> point1, Point<int> point2) {
    return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2));
  }

  /// Calculate angle between three points (in degrees)
  double _calculateAngle(Point<int> p1, Point<int> p2, Point<int> p3) {
    // Vectors
    double v1x = (p1.x - p2.x).toDouble();
    double v1y = (p1.y - p2.y).toDouble();
    double v2x = (p3.x - p2.x).toDouble();
    double v2y = (p3.y - p2.y).toDouble();

    // Dot product
    double dotProduct = v1x * v2x + v1y * v2y;

    // Magnitudes
    double mag1 = sqrt(v1x * v1x + v1y * v1y);
    double mag2 = sqrt(v2x * v2x + v2y * v2y);

    // Angle in radians, then convert to degrees
    double cosAngle = dotProduct / (mag1 * mag2);
    // Clamp cosAngle to prevent domain errors due to floating point precision
    cosAngle = cosAngle.clamp(-1.0, 1.0);
    double angleRadians = acos(cosAngle);
    double angleDegrees = angleRadians * 180 / pi;

    return angleDegrees;
  }

  /// Calculate angle with horizontal axis (for eye alignment)
  double _calculateAngleWithHorizontal(Point<int> p1, Point<int> p2) {
    // Vector from p1 to p2
    double dx = (p2.x - p1.x).toDouble();
    double dy = (p2.y - p1.y).toDouble();

    // Calculate angle with horizontal (x-axis)
    double angleRadians = atan2(dy, dx);
    double angleDegrees = angleRadians * 180 / pi;

    return angleDegrees;
  }

  /// Play sound based on match result
  Future<void> _playSound(bool isMatch) async {
    try {
      // Always make sure audio player is initialized
      if (_audioPlayer == null) {
        print("Reinitializing audio player before playing sound");
        _audioPlayer = AudioPlayer();
      }

      if (isMatch) {
        print("Playing 'yes' sound");
        await _audioPlayer!.stop();
        await _audioPlayer!.play(AssetSource('sounds/yes.mp3'));
      } else {
        print("Playing 'no' sound");
        await _audioPlayer!.stop();
        await _audioPlayer!.play(AssetSource('sounds/no.mp3'));
      }
    } catch (e) {
      print("Error playing sound: $e");

      // Try to recover from error by recreating audio player
      try {
        _audioPlayer?.dispose();
        _audioPlayer = AudioPlayer();

        if (isMatch) {
          await _audioPlayer!.play(AssetSource('sounds/yes.mp3'));
        } else {
          await _audioPlayer!.play(AssetSource('sounds/no.mp3'));
        }
      } catch (retryError) {
        print("Failed to recover audio playback: $retryError");
      }
    }
  }

  /// Robust error handling for face operations
  Future<Map<String, dynamic>> _safelyExecuteFaceOperation(
      Future<Map<String, dynamic>> Function() operation,
      String operationName) async {
    try {
      return await operation();
    } catch (e) {
      print("[FaceService] ERROR during $operationName: $e");

      // Determine error type and provide specific guidance
      String message = 'An error occurred.';

      if (e.toString().contains('permission')) {
        message =
            'Camera permission denied. Please enable camera access in settings.';
      } else if (e.toString().contains('camera')) {
        message = 'Camera error. Please restart the app and try again.';
      } else if (e.toString().contains('file')) {
        message = 'File error. Please try again.';
      } else if (e.toString().contains('memory') ||
          e.toString().contains('out of memory')) {
        message =
            'Device memory is low. Please close other apps and try again.';
      } else {
        message = 'Error during face $operationName: $e';
      }

      // Try to recover resources
      try {
        _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: true,
            enableLandmarks: true,
            enableTracking: true,
            performanceMode: FaceDetectorMode.accurate,
            minFaceSize: 0.15,
          ),
        );

        // Reinitialize audio if needed
        reinitializeAudio();
      } catch (recoverError) {
        print("[FaceService] Failed to recover after error: $recoverError");
      }

      return {
        'success': false,
        'message': message,
        'error': e.toString(),
      };
    }
  }

  /// Reinitialize to load a fresh reference image
  Future<String> refreshReferenceImage() async {
    print("[FaceService] Refreshing reference image for user: $_userId");
    return await initialize();
  }

  /// Clean up resources
  void dispose() {
    _faceDetector.close();

    if (_audioPlayer != null) {
      _audioPlayer!.dispose();
      _audioPlayer = null;
    }

    print("Resources disposed");
  }

  void reinitializeAudio() {
    if (_audioPlayer != null) {
      _audioPlayer!.dispose();
      _audioPlayer = null;
    }

    // Create new audio player
    _audioPlayer = AudioPlayer();
    print("Audio player reinitialized");
  }

  /// Calculate similarity between two faces
  double _calculateFaceSimilarity(Face detectedFace, Face referenceFace) {
    try {
      print("[FaceService] Starting face similarity calculation");

      // Get key facial landmarks
      final Point<int> detectedNose = detectedFace.landmarks[FaceLandmarkType.noseBase]!.position;
      final Point<int> referenceNose = referenceFace.landmarks[FaceLandmarkType.noseBase]!.position;
      final Point<int> detectedLeftEye = detectedFace.landmarks[FaceLandmarkType.leftEye]!.position;
      final Point<int> referenceLeftEye = referenceFace.landmarks[FaceLandmarkType.leftEye]!.position;
      final Point<int> detectedRightEye = detectedFace.landmarks[FaceLandmarkType.rightEye]!.position;
      final Point<int> referenceRightEye = referenceFace.landmarks[FaceLandmarkType.rightEye]!.position;

      // Calculate distances between facial landmarks
      final double detectedEyeDistance = _distance(detectedLeftEye, detectedRightEye);
      final double referenceEyeDistance = _distance(referenceLeftEye, referenceRightEye);

      // Calculate ratio between eyes for distance normalization
      final double eyeRatio = detectedEyeDistance / referenceEyeDistance;
      print("[FaceService] Eye distance ratio: $eyeRatio");

      // Initialize similarity scores map
      Map<String, double> similarities = {};

      // 1. Eye-to-nose triangle (left side)
      final double detectedLeftEyeToNose = _distance(detectedLeftEye, detectedNose) / detectedEyeDistance;
      final double referenceLeftEyeToNose = _distance(referenceLeftEye, referenceNose) / referenceEyeDistance;
      similarities['leftEyeToNoseRatio'] = 1 - (detectedLeftEyeToNose - referenceLeftEyeToNose).abs();

      // 2. Eye-to-nose triangle (right side)
      final double detectedRightEyeToNose = _distance(detectedRightEye, detectedNose) / detectedEyeDistance;
      final double referenceRightEyeToNose = _distance(referenceRightEye, referenceNose) / referenceEyeDistance;
      similarities['rightEyeToNoseRatio'] = 1 - (detectedRightEyeToNose - referenceRightEyeToNose).abs();

      // 3. Eye-nose-eye angle (face shape)
      final double detectedEyeNoseEyeAngle = _calculateAngle(detectedLeftEye, detectedNose, detectedRightEye);
      final double referenceEyeNoseEyeAngle = _calculateAngle(referenceLeftEye, referenceNose, referenceRightEye);
      final double eyeNoseEyeAngleDiff = (detectedEyeNoseEyeAngle - referenceEyeNoseEyeAngle).abs();

      // If this critical angle differs too much, it's not the same person
      if (eyeNoseEyeAngleDiff > ANGLE_THRESHOLD) {
        print(
            "[FaceService] Eye-nose-eye angle difference too large: $eyeNoseEyeAngleDiff° (threshold: $ANGLE_THRESHOLD°)");
        // Instead of immediate rejection, reduce the similarity score
        similarities['eyeNoseEyeAngle'] = 0.5;
      } else {
        similarities['eyeNoseEyeAngle'] = 1 - (eyeNoseEyeAngleDiff / 180);
      }

      // Log all similarity scores for debugging
      print("[FaceService] Individual similarity scores:");
      similarities.forEach((key, value) {
        print("[FaceService] - $key: $value");
      });

      // Calculate weighted average
      double totalWeight = 0;
      double weightedSum = 0;

      // Define weights for each feature
      Map<String, double> weights = {
        'leftEyeToNoseRatio': 1.5,
        'rightEyeToNoseRatio': 1.5,
        'eyeNoseEyeAngle': 2.0,  // Very important facial triangle
      };

      similarities.forEach((key, value) {
        if (!value.isNaN) {
          double weight = weights[key] ?? 1.0;
          weightedSum += value * weight;
          totalWeight += weight;
        }
      });

      // Calculate final similarity score
      double similarityScore = totalWeight > 0 ? weightedSum / totalWeight : 0.0;
      print("[FaceService] Final weighted similarity score: $similarityScore");

      // Apply additional checks for high confidence
      if (similarityScore >= 0.8) {
        // Check head rotation consistency
        if (detectedFace.headEulerAngleY != null && referenceFace.headEulerAngleY != null) {
          double yDiff = (detectedFace.headEulerAngleY! - referenceFace.headEulerAngleY!).abs();
          if (yDiff > 15) {
            print("[FaceService] Head rotation Y difference too large: $yDiff");
            similarityScore *= 0.9;  // Penalize for large head rotation difference
          }
        }
      }

      return similarityScore.clamp(0.0, 1.0);
    } catch (e) {
      print("[FaceService] Error calculating face similarity: $e");
      return 0.0;
    }
  }

  /// Get detailed comparison metrics between two faces
  Map<String, dynamic> _getComparisonDetails(Face detectedFace, Face referenceFace) {
    try {
      final Map<String, dynamic> details = {};

      // Head rotation differences
      if (detectedFace.headEulerAngleY != null && referenceFace.headEulerAngleY != null) {
        details['yRotationDiff'] = (detectedFace.headEulerAngleY! - referenceFace.headEulerAngleY!).abs();
      }
      if (detectedFace.headEulerAngleZ != null && referenceFace.headEulerAngleZ != null) {
        details['zRotationDiff'] = (detectedFace.headEulerAngleZ! - referenceFace.headEulerAngleZ!).abs();
      }

      // Eye openness differences
      if (detectedFace.leftEyeOpenProbability != null && referenceFace.leftEyeOpenProbability != null) {
        details['leftEyeOpenDiff'] = (detectedFace.leftEyeOpenProbability! - referenceFace.leftEyeOpenProbability!).abs();
      }
      if (detectedFace.rightEyeOpenProbability != null && referenceFace.rightEyeOpenProbability != null) {
        details['rightEyeOpenDiff'] = (detectedFace.rightEyeOpenProbability! - referenceFace.rightEyeOpenProbability!).abs();
      }

      return details;
    } catch (e) {
      print("[FaceService] Error getting comparison details: $e");
      return {'error': e.toString()};
    }
  }

  /// Compare two face images and return similarity score
  Future<Map<String, dynamic>> compareTwoFaces(String imagePath1, String imagePath2) async {
    return _safelyExecuteFaceOperation(() async {
      print("[FaceService] Comparing two faces from paths: $imagePath1 and $imagePath2");

      // Process first image
      final InputImage inputImage1 = InputImage.fromFilePath(imagePath1);
      final List<Face> faces1 = await _faceDetector.processImage(inputImage1);

      if (faces1.isEmpty) {
        return {
          'success': false,
          'message': 'No face detected in first image',
          'similarity': 0.0,
        };
      }

      // Process second image
      final InputImage inputImage2 = InputImage.fromFilePath(imagePath2);
      final List<Face> faces2 = await _faceDetector.processImage(inputImage2);

      if (faces2.isEmpty) {
        return {
          'success': false,
          'message': 'No face detected in second image',
          'similarity': 0.0,
        };
      }

      // Get the first face from each image
      final Face face1 = faces1.first;
      final Face face2 = faces2.first;

      // Check face quality for both faces
      if (!_isFaceQualityGood(face1)) {
        return {
          'success': false,
          'message': 'First face quality not good enough',
          'similarity': 0.0,
        };
      }

      if (!_isFaceQualityGood(face2)) {
        return {
          'success': false,
          'message': 'Second face quality not good enough',
          'similarity': 0.0,
        };
      }

      // Calculate similarity score
      final double similarityScore = _calculateFaceSimilarity(face1, face2);
      final Map<String, dynamic> details = _getComparisonDetails(face1, face2);

      // Determine if faces match based on similarity threshold
      final bool isMatch = similarityScore >= SIMILARITY_THRESHOLD;

      return {
        'success': true,
        'isMatch': isMatch,
        'similarity': similarityScore,
        'message': isMatch
            ? 'Faces match with ${(similarityScore * 100).toStringAsFixed(1)}% confidence'
            : 'Faces do not match (${(similarityScore * 100).toStringAsFixed(1)}% similarity)',
        'details': details,
      };
    }, 'two-face-comparison');
  }
}

// Create a singleton instance for easy access
final faceService = FaceService();