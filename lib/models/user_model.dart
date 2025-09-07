class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;
  final String appRole;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.appRole,
  });

  // This factory constructor correctly deserializes a map from Firestore.
  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? 'No Name',
      email: data['email'] ?? 'No Email',
      photoURL: data['photoURL'] ?? '',
      appRole: data['appRole'] ?? 'student',
    );
  }
}

