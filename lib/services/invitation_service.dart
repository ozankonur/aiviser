import 'package:aiviser/models/event_image.dart';
import 'package:aiviser/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  Future<bool> canCreateEvent() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final eventsToday = await _firestore
        .collection('events')
        .where('owner', isEqualTo: currentUser.uid)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledTime', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return eventsToday.docs.length < 3;
  }

  Future<void> createOrUpdateEvent(
      String placeId, Map<String, dynamic> place, DateTime scheduledTime, List<String> invitees) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    bool isVerified = await _authService.isEmailVerified();
    if (!isVerified) {
      throw Exception('Email not verified. Please verify your email to create events.');
    }

    if (!await canCreateEvent()) {
      throw Exception('You have reached the maximum number of events for today.');
    }

    final eventData = {
      'placeId': placeId,
      'placeName': place['name'],
      'placeLatitude': place['location'].latitude,
      'placeLongitude': place['location'].longitude,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'owner': currentUser.uid,
      'participants': FieldValue.arrayUnion([currentUser.uid, ...invitees]),
      'invitationStatuses': {
        currentUser.uid: 'accepted',
        ...{for (var e in invitees) e: 'pending'},
      },
    };

    // Check if an event for this place and time already exists
    final existingEventQuery = await _firestore
        .collection('events')
        .where('placeId', isEqualTo: placeId)
        .where('scheduledTime', isEqualTo: Timestamp.fromDate(scheduledTime))
        .where('owner', isEqualTo: currentUser.uid)
        .get();

    if (existingEventQuery.docs.isNotEmpty) {
      // Update existing event
      final existingEventDoc = existingEventQuery.docs.first;
      await existingEventDoc.reference.update(eventData);
    } else {
      // Create new event
      await _firestore.collection('events').add(eventData);
    }
  }

  Stream<QuerySnapshot> getUserEvents() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    return _firestore.collection('events').where('participants', arrayContains: currentUser.uid).snapshots();
  }

  Stream<QuerySnapshot> getUserOldEvents() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final DateTime now = DateTime.now();

    return _firestore
        .collection('events')
        .where('participants', arrayContains: currentUser.uid)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('scheduledTime', descending: false)
        .snapshots();
  }

  Future<void> updateInvitationStatus(String eventId, String status) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    bool isVerified = await _authService.isEmailVerified();
    if (!isVerified) {
      throw Exception('Email not verified. Please verify your email to update invitation status.');
    }

    await _firestore.collection('events').doc(eventId).update({
      'invitationStatuses.${currentUser.uid}': status,
    });
  }

  Stream<QuerySnapshot> getPendingInvitations() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('events')
        .where('participants', arrayContains: currentUser.uid)
        .where('invitationStatuses.${currentUser.uid}', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> addParticipantToEvent(String eventId, String participantId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Get the current event data
    DocumentSnapshot eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      throw Exception('Event not found');
    }

    Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;

    // Update the participants list and invitationStatuses
    List<String> participants = List<String>.from(eventData['participants'] ?? []);
    Map<String, String> invitationStatuses = Map<String, String>.from(eventData['invitationStatuses'] ?? {});

    if (!participants.contains(participantId)) {
      participants.add(participantId);
      invitationStatuses[participantId] = 'pending';

      // Update the event document
      await _firestore.collection('events').doc(eventId).update({
        'participants': participants,
        'invitationStatuses': invitationStatuses,
      });
    }
  }

  Stream<List<DocumentSnapshot>> getNearbyEvents(LatLng userLocation, double radiusInKm) {
    final double radiusInDegrees = radiusInKm / 111.32; // Approximate degrees for 1 km at the equator

    return _firestore
        .collection('events')
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.now())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final eventData = doc.data();
        final double? eventLatitude = eventData['placeLatitude'] as double?;
        final double? eventLongitude = eventData['placeLongitude'] as double?;

        if (eventLatitude == null || eventLongitude == null) {
          print('Warning: Event ${doc.id} has incomplete location data');
          return false;
        }

        // Calculate distance between user and event
        final latDiff = (userLocation.latitude - eventLatitude).abs();
        final lngDiff = (userLocation.longitude - eventLongitude).abs();
        final distance = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);

        return distance <= radiusInDegrees;
      }).toList();
    });
  }

  Future<void> addImageToEvent(String eventId, String imageUrl, GeoPoint location) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final eventImage = EventImage(
      id: '',
      eventId: eventId,
      userId: currentUser.uid,
      imageUrl: imageUrl,
      location: location,
      timestamp: DateTime.now(),
    );

    await _firestore.collection('event_images').add(eventImage.toMap());
  }

  Stream<List<EventImage>> getEventImages(String eventId) {
    final query = _firestore
        .collection('event_images')
        .where('eventId', isEqualTo: eventId)
        .orderBy('timestamp', descending: true);

    return query.snapshots(includeMetadataChanges: true).asyncMap((snapshot) async {
      if (snapshot.metadata.isFromCache) {
        print('Data is from cache, fetching from server...');
        try {
          QuerySnapshot freshSnapshot = await query.get(GetOptions(source: Source.server));
          return freshSnapshot.docs.map((doc) {
            return EventImage.fromFirestore(doc);
          }).toList();
        } catch (e) {
          print('Error fetching from server: $e');
          // If there's an error fetching from server, return the cached data
          return snapshot.docs.map((doc) => EventImage.fromFirestore(doc)).toList();
        }
      } else {
        return snapshot.docs.map((doc) {
          return EventImage.fromFirestore(doc);
        }).toList();
      }
    }).handleError((error) {
      print('Error in getEventImages stream: $error');
      // Return an empty list on error
      return <EventImage>[];
    });
  }

  Future<bool> isUserNearEvent(String eventId, LatLng userLocation) async {
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      return false;
    }

    final eventData = eventDoc.data() as Map<String, dynamic>;
    final eventLocation = LatLng(eventData['placeLatitude'], eventData['placeLongitude']);

    // Calculate distance between user and event (you may want to adjust the threshold)
    const double thresholdInMeters = 100;
    final distance = _calculateDistance(userLocation, eventLocation);

    return distance <= thresholdInMeters;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // in meters
    final double lat1 = _degreesToRadians(point1.latitude);
    final double lon1 = _degreesToRadians(point1.longitude);
    final double lat2 = _degreesToRadians(point2.latitude);
    final double lon2 = _degreesToRadians(point2.longitude);

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
