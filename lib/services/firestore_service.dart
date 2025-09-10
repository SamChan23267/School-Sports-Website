// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserProfile(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final snapshot = await userRef.get();

    if (!snapshot.exists) {
      try {
        await userRef.set({
          'uid': user.uid,
          'displayName': user.displayName ?? 'No Name',
          'email': user.email ?? 'No Email',
          'photoURL': user.photoURL ?? '',
          'appRole': 'student',
          'followedTeams': [],
        });
      } on FirebaseException catch (e) {
        print(
            "[FirestoreService] A FirebaseException occurred creating a new profile: ${e.message}");
        rethrow;
      }
    } else {
      try {
        await userRef.update({
          'displayName': user.displayName ?? 'No Name',
          'email': user.email ?? 'No Email',
          'photoURL': user.photoURL ?? '',
        });
      } on FirebaseException catch (e) {
        print(
            "[FirestoreService] A FirebaseException occurred updating an existing profile: ${e.message}");
        rethrow;
      }
    }
  }

  Stream<UserModel> getUserStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => UserModel.fromFirestore(snapshot.data() ?? {}));
  }

  Stream<List<TeamModel>> getTeamsForUser(String userId) {
    return _db
        .collection('teams')
        .where('members.$userId', isNotEqualTo: null)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromFirestore(doc)).toList();
    });
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data()))
        .toList();
  }

  Future<List<TeamModel>> getAllTeams() async {
    final snapshot = await _db.collection('teams').get();
    return snapshot.docs.map((doc) => TeamModel.fromFirestore(doc)).toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _db.collection('users').doc(userId).update({'appRole': newRole});
  }

  // --- UPDATED METHOD ---
  Future<void> createTeam(String teamName, UserModel owner) async {
    await _db.collection('teams').add({
      'teamName': teamName,
      'sport': null, // Sport is explicitly set to null as it's not needed
      'members': {
        owner.uid: 'owner',
      },
    });
  }

  // --- NEW METHOD ---
  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  // --- NEW METHOD ---
  Future<void> deleteTeam(String teamId) async {
    await _db.collection('teams').doc(teamId).delete();
  }

  Future<void> followTeam(String userId, String teamName) async {
    await _db.collection('users').doc(userId).update({
      'followedTeams': FieldValue.arrayUnion([teamName])
    });
  }

  Future<void> unfollowTeam(String userId, String teamName) async {
    await _db.collection('users').doc(userId).update({
      'followedTeams': FieldValue.arrayRemove([teamName])
    });
  }
}

