import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// --- UPDATED with Enhanced Error Handling ---
  Future<void> createUserProfile(User user) async {
    final userRef = _db.collection('users').doc(user.uid);

    try {
      // This "upsert" operation attempts to write to the database.
      await userRef.set(
        {
          'uid': user.uid,
          'displayName': user.displayName ?? 'No Name',
          'email': user.email ?? 'No Email',
          'photoURL': user.photoURL ?? '',
          'appRole': 'student',
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      // This will catch specific Firebase errors and give us a much better message.
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      print("[FirestoreService] A FirebaseException occurred:");
      print("Code: ${e.code}"); // e.g., 'permission-denied'
      print("Message: ${e.message}");
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      // Re-throw the exception so the UserProvider still knows something went wrong.
      rethrow;
    } catch (e) {
      // Catch any other unexpected errors.
      print("[FirestoreService] An unknown error occurred: $e");
      rethrow;
    }
  }

  Stream<UserModel> getUserStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => UserModel.fromFirestore(snapshot.data() ?? {}));
  }
}
