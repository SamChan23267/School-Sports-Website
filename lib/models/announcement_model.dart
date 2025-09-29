// lib/models/announcement_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  final String id;
  final String authorId;
  final String authorName;
  final String title; // New: For the announcement title
  final String content;
  final Timestamp timestamp;
  final Map<String, List<String>>
      reactions; // New: Emoji -> List of User UIDs
  final int replyCount; // New: To show the number of replies

  AnnouncementModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.reactions,
    required this.replyCount,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handles the new reactions field, which might not exist on old documents
    final reactionsData = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = reactionsData.map(
      (key, value) => MapEntry(key, List<String>.from(value)),
    );

    return AnnouncementModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown Author',
      title: data['title'] ?? 'Untitled',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      reactions: reactions,
      replyCount: data['replyCount'] ?? 0,
    );
  }
}

// New: Model for replies
class ReplyModel {
  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final Timestamp timestamp;

  ReplyModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
  });

  factory ReplyModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReplyModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown Author',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
