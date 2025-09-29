// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';
import '../models/announcement_model.dart';
import '../models/event_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- User Methods ---
  Future<void> createUserProfile(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    if (!snapshot.exists) {
      await userRef.set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'No Name',
        'email': user.email ?? 'No Email',
        'photoURL': user.photoURL ?? '',
        'appRole': 'student',
        'followedTeams': [],
      });
    }
  }

  Stream<UserModel> getUserStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => UserModel.fromFirestore(snapshot.data() ?? {}));
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data()))
        .toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _db.collection('users').doc(userId).update({'appRole': newRole});
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final querySnapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return UserModel.fromFirestore(querySnapshot.docs.first.data());
    }
    return null;
  }

  // --- Followed Teams Methods ---
  Future<void> followTeam(
      String userId, String sportName, String teamName) async {
    final uniqueTeamId = '$sportName::$teamName';
    await _db.collection('users').doc(userId).update({
      'followedTeams': FieldValue.arrayUnion([uniqueTeamId])
    });
  }

  Future<void> unfollowTeam(
      String userId, String sportName, String teamName) async {
    final uniqueTeamId = '$sportName::$teamName';
    await _db.collection('users').doc(userId).update({
      'followedTeams': FieldValue.arrayRemove([uniqueTeamId])
    });
  }

  // --- Classroom Team Methods ---
  Stream<List<TeamModel>> getTeamsForUser(String userId) {
    return _db
        .collection('teams')
        .where('members.$userId', isNotEqualTo: null)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromFirestore(doc)).toList();
    });
  }
  
  Stream<TeamModel> getTeamStream(String teamId) {
    return _db.collection('teams').doc(teamId).snapshots().map((snapshot) {
      return TeamModel.fromFirestore(snapshot);
    });
  }


  /// Fetches all teams from the database. This is used for the Admin Panel.
  Future<List<TeamModel>> getAllTeams() async {
    final snapshot = await _db.collection('teams').get();
    return snapshot.docs.map((doc) => TeamModel.fromFirestore(doc)).toList();
  }
  
  Future<void> createTeam(String teamName, UserModel owner) async {
    await _db.collection('teams').add({
      'teamName': teamName,
      'sport': null,
      'members': {
        owner.uid: 'owner',
      },
    });
  }

  Future<void> deleteTeam(String teamId) async {
    await _db.collection('teams').doc(teamId).delete();
  }

  Future<void> updateTeamName(String teamId, String newName) async {
    await _db.collection('teams').doc(teamId).update({'teamName': newName});
  }

  // --- Roster Management ---
  Future<void> addTeamMember(
      String teamId, String userId, String role) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .update({'members.$userId': role});
  }

  Future<void> updateTeamMemberRole(String teamId, String userId, String newRole) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .update({'members.$userId': newRole});
  }

  Future<void> removeTeamMember(String teamId, String userId) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .update({'members.$userId': FieldValue.delete()});
  }

  // --- Announcements ---
  Future<void> postAnnouncement(
      String teamId, UserModel author, String content) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .collection('announcements')
        .add({
      'authorId': author.uid,
      'authorName': author.displayName,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AnnouncementModel>> getAnnouncementsStream(String teamId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnnouncementModel.fromFirestore(doc))
            .toList());
  }

  // --- Events ---
  Future<void> createEvent(String teamId, String title, String? description,
      DateTime eventDate, UserModel author) async {
    await _db.collection('teams').doc(teamId).collection('events').add({
      'title': title,
      'description': description,
      'eventDate': Timestamp.fromDate(eventDate),
      'createdBy': author.displayName,
    });
  }

  Stream<List<EventModel>> getEventsStream(String teamId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('events')
        .orderBy('eventDate', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }
}

