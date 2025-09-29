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
  Stream<TeamModel> getTeamStream(String teamId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .snapshots()
        .map((snapshot) => TeamModel.fromFirestore(snapshot));
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

  Future<void> removeTeamMember(String teamId, String userId) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .update({'members.$userId': FieldValue.delete()});
  }

  Future<void> updateTeamMemberRole(
      String teamId, String userId, String newRole) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .update({'members.$userId': newRole});
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
      DateTime startDate, DateTime? endDate, UserModel author) async {
    await _db.collection('teams').doc(teamId).collection('events').add({
      'title': title,
      'description': description,
      'eventDate': Timestamp.fromDate(startDate),
      'eventEndDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      'createdBy': author.uid,
      'authorName': author.displayName,
      'responses': {},
    });
  }

  Future<void> updateEvent(String teamId, String eventId, String title,
      String? description, DateTime startDate, DateTime? endDate) async {
    await _db.collection('teams').doc(teamId).collection('events').doc(eventId).update({
      'title': title,
      'description': description,
      'eventDate': Timestamp.fromDate(startDate),
      'eventEndDate': endDate != null ? Timestamp.fromDate(endDate) : null,
    });
  }

  Future<void> deleteEvent(String teamId, String eventId) async {
    await _db.collection('teams').doc(teamId).collection('events').doc(eventId).delete();
  }
  
  Future<void> respondToEvent(String teamId, String eventId, String userId, String status) async {
    await _db.collection('teams').doc(teamId).collection('events').doc(eventId).update({
      'responses.$userId': status,
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

  // New: Stream for a single event
  Stream<EventModel> getEventStream(String teamId, String eventId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((snapshot) => EventModel.fromFirestore(snapshot));
  }
}

