import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

/// A service class for handling Firebase authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    try {
      // Try the normal login method
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if we're actually logged in by getting the current user
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print("Login succeeded, current user UID: ${currentUser.uid}");
        return true; // Authentication successful
      } else {
        print("Login failed: User is null after authentication");
        return false;
      }
    } catch (e) {
      // If we got the PigeonUserDetails error but might still be authenticated
      if (e.toString().contains('PigeonUserDetails')) {
        // Check if we're actually logged in despite the error
        await Future.delayed(
            const Duration(milliseconds: 500)); // Give Firebase a moment
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          print(
              "Login succeeded despite PigeonUserDetails error: ${currentUser.uid}");
          return true; // Authentication successful despite the error
        }
      }

      // Other errors are actual auth failures
      print("Login error: $e");
      return false;
    }
  }

  /// Sign up with email and password and store face image
  Future<bool> signUp(
      {required String email,
      required String password,
      String? username,
      String? faceImageBase64}) async {
    try {
      // Try the normal signup method
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if we're actually registered by getting the current user
      final currentUser = userCredential.user;
      if (currentUser != null) {
        print("Signup succeeded, current user UID: ${currentUser.uid}");

        // Save user data to Firestore
        bool savedToFirestore = await databaseService.saveUserData(
          userId: currentUser.uid,
          email: email,
          username: username,
          faceImageBase64: faceImageBase64,
        );

        if (!savedToFirestore) {
          print("Warning: User created but data not saved to Firestore");
        }

        return true; // Registration successful
      } else {
        print("Signup failed: User is null after registration");
        return false;
      }
    } catch (e) {
      // If we got the PigeonUserDetails error but might still be authenticated
      if (e.toString().contains('PigeonUserDetails')) {
        // Check if we're actually registered despite the error
        await Future.delayed(
            const Duration(milliseconds: 500)); // Give Firebase a moment
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          print(
              "Signup succeeded despite PigeonUserDetails error: ${currentUser.uid}");

          // Save user data to Firestore
          bool savedToFirestore = await databaseService.saveUserData(
            userId: currentUser.uid,
            email: email,
            username: username,
            faceImageBase64: faceImageBase64,
          );

          if (!savedToFirestore) {
            print("Warning: User created but data not saved to Firestore");
          }

          return true; // Registration successful despite the error
        }
      }

      // Other errors are actual auth failures
      print("Signup error: $e");
      return false;
    }
  }

  /// Update user's face image

  /// Get user's face image for recognition
  Future<String?> getUserFaceImage() async {
    try {
      final user = currentUser;
      if (user == null) {
        print("Cannot get face image: No user is logged in");
        return null;
      }

      return await databaseService.getUserFaceImage(user.uid);
    } catch (e) {
      print("Error getting user face image: $e");
      return null;
    }
  }

  /// Get current user profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) {
        print("Cannot get user profile: No user is logged in");
        return null;
      }

      return await databaseService.getUserData(user.uid);
    } catch (e) {
      print("Error getting user profile: $e");
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final user = currentUser;
      if (user == null) {
        print("Cannot update profile: No user is logged in");
        return false;
      }

      return await databaseService.updateUserProfile(user.uid, profileData);
    } catch (e) {
      print("Error updating user profile: $e");
      return false;
    }
  }

  /// Update username
  Future<bool> updateUsername(String username) async {
    try {
      final user = currentUser;
      if (user == null) {
        print("Cannot update username: No user is logged in");
        return false;
      }

      return await databaseService.updateUsername(user.uid, username);
    } catch (e) {
      print("Error updating username: $e");
      return false;
    }
  }

  Future<bool> updateFaceImage(String faceImageBase64) async {
    try {
      final user = currentUser;
      if (user == null) {
        print("Cannot update face image: No user is logged in");
        return false;
      }

      return await databaseService.updateUserFaceImage(
          user.uid, faceImageBase64);
    } catch (e) {
      print("Error updating face image: $e");
      return false;
    }
  }

  /// Update user's email (requires re-authentication)
  Future<bool> updateEmail(String newEmail, String password) async {
    try {
      final user = currentUser;
      if (user == null) {
        print("Cannot update email: No user is logged in");
        return false;
      }

      if (user.email == null) {
        print("Cannot update email: Current user has no email");
        return false;
      }

      // Re-authenticate user first
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        print("User re-authenticated successfully");
      } catch (e) {
        print("Re-authentication failed: $e");
        return false;
      }

      // Update email in Firebase Auth
      await user.updateEmail(newEmail);

      // Update email in Firestore
      await databaseService.updateEmail(user.uid, newEmail);

      print("Email updated successfully");
      return true;
    } catch (e) {
      print("Error updating email: $e");
      return false;
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print("Password reset email sent to: $email");
      return true;
    } catch (e) {
      print("Password reset error: $e");
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// Create a singleton instance
final authService = AuthService();
