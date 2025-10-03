// lib/services/firestore_service.dart
import 'dart:math';
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
    final displayName = user.displayName ?? 'No Name';

    if (!snapshot.exists) {
      // New user, create the profile with the lowercase field
      await userRef.set({
        'uid': user.uid,
        'displayName': displayName,
        'displayName_lowercase': displayName.toLowerCase(),
        'email': user.email ?? 'No Email',
        'photoURL': user.photoURL ?? '',
        'appRole': 'student',
        'followedTeams': [],
      });
    } else {
      // Existing user, check if the lowercase field is missing and add it.
      // This makes existing users searchable by name after they log in again.
      final data = snapshot.data();
      if (data != null && data['displayName_lowercase'] == null) {
        await userRef.update({
          'displayName_lowercase': displayName.toLowerCase(),
        });
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

  /// Fetches an initial list of users to display.
  Future<List<UserModel>> getAllUsers() async {
    // We limit the initial fetch to avoid loading the entire user base at once.
    final snapshot = await _db.collection('users').limit(20).get();
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

  /// Searches for users by display name or email. Now case-insensitive.
  /// If the query is empty, it returns an initial list of all users.
  Future<List<UserModel>> searchUsers(String query) async {
    // If the search box is empty, show an initial list of users.
    if (query.isEmpty) {
      return getAllUsers();
    }
    final lowerCaseQuery = query.toLowerCase();

    // This type of query finds documents where the field value starts with the search query.
    // It's the most efficient way to build "search-as-you-type" with Firestore.
    final nameQuery = _db
        .collection('users')
        .where('displayName_lowercase', isGreaterThanOrEqualTo: lowerCaseQuery)
        .where('displayName_lowercase',
            isLessThanOrEqualTo: '$lowerCaseQuery\uf8ff')
        .limit(5);

    final emailQuery = _db
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: lowerCaseQuery)
        .where('email', isLessThanOrEqualTo: '$lowerCaseQuery\uf8ff')
        .limit(5);

    // Run both queries in parallel.
    final results = await Future.wait([nameQuery.get(), emailQuery.get()]);
    final nameResults = results[0];
    final emailResults = results[1];

    // Use a Map to combine and automatically de-duplicate the results.
    final Map<String, UserModel> users = {};
    for (var doc in nameResults.docs) {
      final user = UserModel.fromFirestore(doc.data());
      users[user.uid] = user;
    }
    for (var doc in emailResults.docs) {
      final user = UserModel.fromFirestore(doc.data());
      users[user.uid] = user;
    }

    return users.values.toList();
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
      'joinCodeEnabled': false,
      'joinCode': null,
    });
  }

  Future<void> deleteTeam(String teamId) async {
    await _db.collection('teams').doc(teamId).delete();
  }

  Future<void> updateTeamName(String teamId, String newName) async {
    await _db.collection('teams').doc(teamId).update({'teamName': newName});
  }

  // --- Join Code Methods ---
  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> updateJoinCodeSettings(
      {required String teamId, required bool enabled}) async {
    if (enabled) {
      // Generate a new code every time it's enabled
      final newCode = _generateJoinCode();
      await _db
          .collection('teams')
          .doc(teamId)
          .update({'joinCodeEnabled': true, 'joinCode': newCode});
    } else {
      // Disable and remove the code
      await _db
          .collection('teams')
          .doc(teamId)
          .update({'joinCodeEnabled': false, 'joinCode': null});
    }
  }

  Future<String> joinTeamWithCode(
      {required String code, required String userId}) async {
    final querySnapshot = await _db
        .collection('teams')
        .where('joinCode', isEqualTo: code.toUpperCase())
        .where('joinCodeEnabled', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Invalid or expired join code.');
    }

    final teamDoc = querySnapshot.docs.first;
    final team = TeamModel.fromFirestore(teamDoc);

    if (team.members.containsKey(userId)) {
      throw Exception('You are already a member of ${team.teamName}.');
    }

    await addTeamMember(team.id, userId, 'member');
    return team.teamName;
  }

  // --- Roster Management ---
  Future<void> addTeamMember(
      String teamId, String userId, String role) async {
    await _db.collection('teams').doc(teamId).update({'members.$userId': role});
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

  Future<void> transferOwnership(
      String teamId, String newOwnerId, String oldOwnerId) async {
    final teamRef = _db.collection('teams').doc(teamId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(teamRef);
      if (!snapshot.exists) {
        throw Exception("Team does not exist!");
      }

      // Prepare the updates
      transaction.update(teamRef, {
        'members.$newOwnerId': 'owner',
        'members.$oldOwnerId': 'manager', // Demote the old owner
      });
    });
  }

  // --- Announcements ---
  Future<void> postAnnouncement(
      String teamId, UserModel author, String title, String content) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .collection('announcements')
        .add({
      'authorId': author.uid,
      'authorName': author.displayName,
      'title': title,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
      'replyCount': 0,
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

  Future<void> toggleReaction(String teamId, String announcementId,
      String userId, String emoji) async {
    final docRef = _db
        .collection('teams')
        .doc(teamId)
        .collection('announcements')
        .doc(announcementId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception("Announcement does not exist!");
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final reactions =
          Map<String, List<dynamic>>.from(data['reactions'] ?? {});

      reactions.forEach((key, value) {
        value.remove(userId);
      });

      if (reactions[emoji]?.contains(userId) != true) {
        reactions.update(emoji, (value) => value..add(userId),
            ifAbsent: () => [userId]);
      }

      transaction.update(docRef, {'reactions': reactions});
    });
  }

  Future<void> addReplyToAnnouncement(String teamId, String announcementId,
      UserModel author, String content) async {
    final announcementRef = _db
        .collection('teams')
        .doc(teamId)
        .collection('announcements')
        .doc(announcementId);
    final replyRef = announcementRef.collection('replies');

    await _db.runTransaction((transaction) async {
      transaction.set(replyRef.doc(), {
        'authorId': author.uid,
        'authorName': author.displayName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
      });
      transaction
          .update(announcementRef, {'replyCount': FieldValue.increment(1)});
    });
  }

  Stream<List<ReplyModel>> getRepliesStream(
      String teamId, String announcementId) {
    return _db
        .collection('teams')
        .doc(teamId)
        .collection('announcements')
        .doc(announcementId)
        .collection('replies')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReplyModel.fromFirestore(doc)).toList());
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
    await _db
        .collection('teams')
        .doc(teamId)
        .collection('events')
        .doc(eventId)
        .update({
      'title': title,
      'description': description,
      'eventDate': Timestamp.fromDate(startDate),
      'eventEndDate': endDate != null ? Timestamp.fromDate(endDate) : null,
    });
  }

  Future<void> deleteEvent(String teamId, String eventId) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .collection('events')
        .doc(eventId)
        .delete();
  }

  Future<void> respondToEvent(
      String teamId, String eventId, String userId, String status) async {
    await _db
        .collection('teams')
        .doc(teamId)
        .collection('events')
        .doc(eventId)
        .update({
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
