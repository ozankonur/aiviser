import 'package:aiviser/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvitationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

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
}
