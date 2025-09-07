// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
// The google_sign_in import is no longer needed for this web-only implementation.
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        // Create a new provider
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // The web-only SDK handles the popup UI.
        final userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential;

      } on FirebaseAuthException catch (e) {
        // Keeping error logs is useful for production
        print("AuthService Error: A Firebase Auth Exception occurred: ${e.message}");
        return null;
      } catch (e) {
        print("AuthService Error: An unknown error occurred: $e");
        return null;
      }
    } else {
      // For mobile platforms, you would use the google_sign_in package differently
      // but this implementation is focused on the web issue.
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      // With the latest plugins, calling signOut on FirebaseAuth is sufficient.
      // It handles clearing the session for all providers, including Google.
      await _auth.signOut();
      
      // The explicit call to GoogleSignIn().signOut() is no longer needed with
      // this sign-in method and the new package versions.

    } catch (e) {
      print("Error during sign out: $e");
    }
  }
}

