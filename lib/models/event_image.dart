import 'package:cloud_firestore/cloud_firestore.dart';

class EventImage {
  final String id;
  final String eventId;
  final String userId;
  final String imageUrl;
  final GeoPoint location;
  final DateTime timestamp;

  EventImage({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.imageUrl,
    required this.location,
    required this.timestamp,
  });

  factory EventImage.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return EventImage(
      id: doc.id,
      eventId: data['eventId'],
      userId: data['userId'],
      imageUrl: data['imageUrl'],
      location: data['location'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'imageUrl': imageUrl,
      'location': location,
      'timestamp': timestamp,
    };
  }
}