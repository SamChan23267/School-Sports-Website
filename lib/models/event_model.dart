// lib/models/event_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String? description;
  final Timestamp eventDate;
  final Timestamp? eventEndDate; // New: For event duration
  final String createdBy; // UID of the creator
  final String authorName; // Display name of the creator
  final Map<String, String>
      responses; // New: Map of UID to status ('going', 'maybe', 'not_going')
  final String teamId; // ID of the team this event belongs to

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    this.eventEndDate,
    required this.createdBy,
    required this.authorName,
    required this.responses,
    required this.teamId,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? 'Untitled Event',
      description: data['description'],
      eventDate: data['eventDate'] ?? Timestamp.now(),
      eventEndDate: data['eventEndDate'],
      createdBy: data['createdBy'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      responses: Map<String, String>.from(data['responses'] ?? {}),
      teamId: data['teamId'] ?? '',
    );
  }
}

