import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/welcome_screen.dart';
import 'utils/constants.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Configure Firestore settings
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true, // Enable offline persistence
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Unlimited cache size
    );

    print("Firebase initialized successfully");

    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      print("Camera permission not granted");
    }

    // Request storage permission for image picking
    final storageStatus = await Permission.storage.request();
    if (!storageStatus.isGranted) {
      print("Storage permission not granted");
    }

    // Get available cameras
    final cameras = await availableCameras();
    final firstCamera = cameras.isEmpty ? null : cameras.first;

    if (cameras.isEmpty) {
      print("No cameras found on device");
    } else {
      print("Found ${cameras.length} cameras on device");
      for (var i = 0; i < cameras.length; i++) {
        print("Camera $i: ${cameras[i].name} (${cameras[i].lensDirection})");
      }
    }

    runApp(MyApp(camera: firstCamera));
  } catch (e) {
    print("Error initializing app: $e");
    // Run a fallback app that shows the error
    runApp(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Initialization Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Failed to initialize app: $e'),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  final CameraDescription? camera;

  const MyApp({Key? key, this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Auth App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          error: AppColors.error,
          background: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: AppTextStyles.headline1,
          displayMedium: AppTextStyles.headline2,
          bodyLarge: AppTextStyles.body,
          titleMedium: AppTextStyles.subtitle,
          labelLarge: AppTextStyles.button,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 2),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
        useMaterial3: true,
      ),
      home: camera == null
          ? const NoCameraScreen()
          : WelcomeScreen(camera: camera!),
      routes: {
        '/welcome': (context) => camera == null
            ? const NoCameraScreen()
            : WelcomeScreen(camera: camera!),
      },
    );
  }
}
