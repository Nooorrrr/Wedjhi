import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/constants.dart';
import '../services/face_service.dart';
import '../widgets/app_button.dart';

class PlaygroundScreen extends StatefulWidget {
  final CameraDescription camera;

  const PlaygroundScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _PlaygroundScreenState createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  File? _image1;
  File? _image2;
  bool _isComparing = false;
  String _comparisonResult = '';
  double _similarityScore = 0.0;
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _getImageFromCamera(int imageNumber) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        if (imageNumber == 1) {
          _image1 = File(image.path);
        } else {
          _image2 = File(image.path);
        }
        _comparisonResult = '';
        _similarityScore = 0.0;
      });
    }
  }

  Future<void> _getImageFromGallery(int imageNumber) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (imageNumber == 1) {
          _image1 = File(image.path);
        } else {
          _image2 = File(image.path);
        }
        _comparisonResult = '';
        _similarityScore = 0.0;
      });
    }
  }

  Future<void> _playSound(bool isMatch) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource(isMatch ? 'sounds/yes.mp3' : 'sounds/no.mp3'),
      );
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _compareImages() async {
    if (_image1 == null || _image2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both images first'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isComparing = true;
      _comparisonResult = 'Comparing faces...';
    });

    try {
      final result = await faceService.compareTwoFaces(
        _image1!.path,
        _image2!.path,
      );

      setState(() {
        _isComparing = false;
        _comparisonResult = result['message'];
        _similarityScore = result['similarity'] ?? 0.0;
      });

      // Play sound based on match result
      await _playSound(result['isMatch'] ?? false);
    } catch (e) {
      setState(() {
        _isComparing = false;
        _comparisonResult = 'Error comparing faces: $e';
      });
    }
  }

  Widget _buildImageSelector(int imageNumber) {
    final image = imageNumber == 1 ? _image1 : _image2;
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: image != null ? AppColors.primary : Colors.grey,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (image != null)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            )
          else
            const Icon(
              Icons.add_a_photo,
              size: 50,
              color: Colors.grey,
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _getImageFromCamera(imageNumber),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              TextButton.icon(
                onPressed: () => _getImageFromGallery(imageNumber),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Comparison Playground'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Compare Two Faces',
              style: AppTextStyles.headline2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildImageSelector(1),
            const SizedBox(height: 16),
            _buildImageSelector(2),
            const SizedBox(height: 24),
            if (_comparisonResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _similarityScore > 0.8
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _similarityScore > 0.8
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _comparisonResult,
                      style: TextStyle(
                        color: _similarityScore > 0.8
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_similarityScore > 0)
                      Text(
                        'Similarity Score: ${(_similarityScore * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _similarityScore > 0.8
                              ? AppColors.success
                              : AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            AppButton(
              text: _isComparing ? 'Comparing...' : 'Compare Faces',
              icon: Icons.compare_arrows,
              isLoading: _isComparing,
              onPressed: _compareImages,
            ),
          ],
        ),
      ),
    );
  }
} 