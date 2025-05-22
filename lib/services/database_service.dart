import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A service class for handling Firestore database operations
class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  // Maximum base64 string size (approximately 1MB in base64)
  static const int MAX_BASE64_SIZE = 1400000;

  /// Add or update user data in Firestore
  Future<bool> saveUserData({
    required String userId,
    required String email,
    String? username,
    String? faceImageBase64,
  }) async {
    try {
      print("[DatabaseService] Saving user data for: $userId");

      // Validate base64 image size if provided
      if (faceImageBase64 != null && faceImageBase64.isNotEmpty) {
        if (faceImageBase64.length > MAX_BASE64_SIZE) {
          print(
              "[DatabaseService] ERROR: Base64 image too large: ${faceImageBase64.length} chars");
          return false;
        }

        // Validate base64 format
        try {
          base64Decode(faceImageBase64);
        } catch (e) {
          print("[DatabaseService] ERROR: Invalid base64 format: $e");
          return false;
        }
      }

      // Create map of user data
      Map<String, dynamic> userData = {
        'email': email,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Only add the username if it's provided
      if (username != null && username.isNotEmpty) {
        userData['username'] = username;
      }

      // Only add the face image if it's provided
      if (faceImageBase64 != null && faceImageBase64.isNotEmpty) {
        userData['faceImageBase64'] = faceImageBase64;
      }

      // For new users, add creation timestamp
      DocumentSnapshot existingDoc = await _usersCollection.doc(userId).get();
      if (!existingDoc.exists) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Save to Firestore with retry mechanism
      bool success = false;
      int retries = 0;
      Exception? lastError;

      while (!success && retries < 3) {
        try {
          await _usersCollection
              .doc(userId)
              .set(userData, SetOptions(merge: true));
          success = true;
          print(
              "[DatabaseService] User data saved to Firestore for user: $userId");
        } catch (e) {
          lastError = e as Exception;
          retries++;
          print("[DatabaseService] Retry $retries: Error saving user data: $e");
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      }

      if (!success) {
        print("[DatabaseService] Failed after $retries retries: $lastError");
        return false;
      }

      return true;
    } catch (e) {
      print("[DatabaseService] ERROR saving user data: $e");
      return false;
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      print("[DatabaseService] Getting user data for: $userId");

      // Get document with timeout
      DocumentSnapshot doc = await _usersCollection
          .doc(userId)
          .get()
          .timeout(Duration(seconds: 10), onTimeout: () {
        throw TimeoutException("Timeout getting user data");
      });

      if (!doc.exists) {
        print("[DatabaseService] No user data found for user: $userId");
        return null;
      }

      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      print("[DatabaseService] Retrieved user data for user: $userId");

      return userData;
    } catch (e) {
      print("[DatabaseService] ERROR getting user data: $e");
      return null;
    }
  }

  /// Get reference face image for a user
  Future<String?> getUserFaceImage(String userId) async {
    try {
      print("[DatabaseService] Getting face image for user: $userId");

      // First try to get just the face image field to reduce data transfer
      DocumentSnapshot doc = await _usersCollection
          .doc(userId)
          .get(GetOptions(source: Source.serverAndCache));

      if (!doc.exists) {
        print("[DatabaseService] No user document found for: $userId");
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (!data.containsKey('faceImageBase64')) {
        print("[DatabaseService] No face image found for user: $userId");
        return null;
      }

      String base64Image = data['faceImageBase64'] as String;

      // Validate the base64 string
      if (base64Image.isEmpty) {
        print("[DatabaseService] Face image is empty for user: $userId");
        return null;
      }

      print(
          "[DatabaseService] Retrieved face image for user: $userId (length: ${base64Image.length})");
      return base64Image;
    } catch (e) {
      print("[DatabaseService] ERROR getting user face image: $e");
      return null;
    }
  }

  /// Update user's face image
  Future<bool> updateUserFaceImage(
      String userId, String faceImageBase64) async {
    try {
      print("[DatabaseService] Updating face image for user: $userId");

      // Validate base64 size
      if (faceImageBase64.length > MAX_BASE64_SIZE) {
        print(
            "[DatabaseService] ERROR: Base64 image too large: ${faceImageBase64.length} chars");
        return false;
      }

      // Validate base64 format
      try {
        base64Decode(faceImageBase64);
      } catch (e) {
        print("[DatabaseService] ERROR: Invalid base64 format: $e");
        return false;
      }

      await _usersCollection.doc(userId).update({
        'faceImageBase64': faceImageBase64,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print("[DatabaseService] Updated face image for user: $userId");
      return true;
    } catch (e) {
      print("[DatabaseService] ERROR updating face image: $e");
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(
      String userId, Map<String, dynamic> profileData) async {
    try {
      print("[DatabaseService] Updating profile for user: $userId");

      // Add timestamp
      profileData['lastUpdated'] = FieldValue.serverTimestamp();

      // Make sure we don't accidentally overwrite critical fields
      profileData.remove(
          'email'); // Email changes should be handled separately for security
      profileData
          .remove('createdAt'); // Created timestamp should never be changed

      await _usersCollection.doc(userId).update(profileData);

      print("[DatabaseService] Successfully updated profile for user: $userId");
      return true;
    } catch (e) {
      print("[DatabaseService] ERROR updating user profile: $e");
      return false;
    }
  }

  /// Update username
  Future<bool> updateUsername(String userId, String username) async {
    try {
      print("[DatabaseService] Updating username for user: $userId");

      if (username.isEmpty) {
        print("[DatabaseService] Username cannot be empty");
        return false;
      }

      await _usersCollection.doc(userId).update({
        'username': username,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print(
          "[DatabaseService] Successfully updated username for user: $userId");
      return true;
    } catch (e) {
      print("[DatabaseService] ERROR updating username: $e");
      return false;
    }
  }

  /// Update email
  Future<bool> updateEmail(String userId, String email) async {
    try {
      print("[DatabaseService] Updating email for user: $userId");

      if (email.isEmpty) {
        print("[DatabaseService] Email cannot be empty");
        return false;
      }

      await _usersCollection.doc(userId).update({
        'email': email,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print("[DatabaseService] Successfully updated email for user: $userId");
      return true;
    } catch (e) {
      print("[DatabaseService] ERROR updating email: $e");
      return false;
    }
  }
}

/// Custom exception for database timeouts
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

// Create a singleton instance
final databaseService = DatabaseService();
