// lib/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream to listen for auth changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      // For web, we use a popup
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      // Optionally, you can add scopes if you need to access Google APIs
      // googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
      
      try {
        return await _auth.signInWithPopup(googleProvider);
      } catch (e) {
        print("Error during Google sign-in with popup: $e");
        return null;
      }
    } else {
      // For mobile platforms (not needed now, but good to have)
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // The user canceled the sign-in
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
