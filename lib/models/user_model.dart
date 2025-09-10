// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;
  final String appRole;
  final List<String> followedTeams; // Will now store composite IDs like "Sport::TeamName"

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.appRole,
    required this.followedTeams,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? 'No Name',
      email: data['email'] ?? 'No Email',
      photoURL: data['photoURL'] ?? '',
      appRole: data['appRole'] ?? 'student',
      followedTeams: List<String>.from(data['followedTeams'] ?? []),
    );
  }
}

