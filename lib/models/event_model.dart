// lib/models/event_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String? description;
  final Timestamp eventDate;
  final String createdBy;

  EventModel({
    required this.id,
    required this.title,
    this.description,
    required this.eventDate,
    required this.createdBy,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? 'Untitled Event',
      description: data['description'],
      eventDate: data['eventDate'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? 'Unknown',
    );
  }
}

