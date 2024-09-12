import 'package:cloud_firestore/cloud_firestore.dart';

class EventMedia {
  final String id;
  final String eventId;
  final String userId;
  final String mediaUrl;
  final Timestamp timestamp;

  EventMedia({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.mediaUrl,
    required this.timestamp,
  });

  factory EventMedia.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return EventMedia(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
    };
  }
}