// lib/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  // --- Singleton Pattern Start ---
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();
  // --- Singleton Pattern End ---

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      try {
        return await _auth.signInWithPopup(googleProvider);
      } catch (e) {
        print("Error during Google sign-in with popup: $e");
        return null;
      }
    } else {
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return null;
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      } catch (e) {
        print("Error during Google sign-in: $e");
        return null;
      }
    }
  }


  // Made the signOut method more robust to prevent crashes.
  Future<void> signOut() async {
    try {
      // Attempt to sign out from Google first. This can sometimes fail if the
      // session is old, but we don't want it to crash the app.
      await _googleSignIn.signOut();
    } catch (e) {
      print("Error during Google sign out: $e");
      // We catch the error but don't rethrow, so that Firebase sign-out can still proceed.
    }

    try {
      // Always sign out from Firebase. This is the most critical step.
      await _auth.signOut();
    } catch (e) {
      print("Error during Firebase sign out: $e");
    }
  }
}

