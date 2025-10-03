// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;
  final String appRole;
  final List<String> followedTeams;
  
  // Expanded user profile fields
  final String? fullName;
  final Timestamp? birthday;
  final String? phoneNumber;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? medicalConditions;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
    required this.appRole,
    required this.followedTeams,
    this.fullName,
    this.birthday,
    this.phoneNumber,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.medicalConditions,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? 'No Name',
      email: data['email'] ?? 'No Email',
      photoURL: data['photoURL'] ?? '',
      appRole: data['appRole'] ?? 'student',
      followedTeams: List<String>.from(data['followedTeams'] ?? []),
      fullName: data['fullName'],
      birthday: data['birthday'],
      phoneNumber: data['phoneNumber'],
      emergencyContactName: data['emergencyContactName'],
      emergencyContactPhone: data['emergencyContactPhone'],
      medicalConditions: data['medicalConditions'],
    );
  }
}

