// lib/models/team_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String teamName;
  final String? sport; // Sport is now optional
  final Map<String, String> members;
  final bool joinCodeEnabled; // New: To enable/disable join code
  final String? joinCode; // New: The 6-digit code for joining

  TeamModel({
    required this.id,
    required this.teamName,
    this.sport,
    required this.members,
    required this.joinCodeEnabled,
    this.joinCode,
  });

  factory TeamModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TeamModel(
      id: doc.id,
      teamName: data['teamName'] ?? 'Unnamed Team',
      sport: data['sport'], // Can be null
      members: Map<String, String>.from(data['members'] ?? {}),
      joinCodeEnabled: data['joinCodeEnabled'] ?? false,
      joinCode: data['joinCode'],
    );
  }
}
