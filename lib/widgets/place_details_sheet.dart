import 'package:aiviser/screens/invite_contact_screen.dart';
import 'package:aiviser/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PlaceDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> place;
  final Function(String) showSnackBar;
  final bool isEventPlace;
  final String? eventId;
  final AuthService _authService = AuthService(); 

  PlaceDetailsSheet({
    Key? key,
    required this.place,
    required this.showSnackBar,
    this.isEventPlace = false,
    this.eventId,
  }) : super(key: key);

  void _navigateToInviteContacts(BuildContext context) async {
    bool isVerified = await _authService.isEmailVerified();
    if (!isVerified) {
      showSnackBar('Please verify your email before inviting users.');
      return;
    }

    if (isEventPlace && eventId != null) {
      // For existing events, navigate directly to InviteContactsScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InviteContactsScreen(
            place: place,
            eventId: eventId!,
          ),
        ),
      );
    } else {
      // For new events, show date picker first
      final DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (selectedDate == null) return;

      final TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime == null) return;

      final DateTime selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InviteContactsScreen(
            place: place,
            scheduledTime: selectedDateTime,
          ),
        ),
      );
    }
  }

  Widget _buildOwnerTile(String userId, Timestamp scheduledTime) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Error loading owner');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final username = userData['username'] ?? 'Unknown User';
        final profileImageUrl = userData['profileImageUrl'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl == null ? Text(username.substring(0, 1).toUpperCase()) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Event Organizer',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(scheduledTime),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.star,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticipantTile(String userId, String status, Timestamp scheduledTime) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Loading...'),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const ListTile(
            leading: Icon(Icons.error),
            title: Text('Error loading user'),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final username = userData['username'] ?? 'Unknown User';
        final profileImageUrl = userData['profileImageUrl'];

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
            child: profileImageUrl == null ? Text(username.substring(0, 1).toUpperCase()) : null,
          ),
          title: Text(username),
          subtitle: Text(_formatDateTime(scheduledTime)),
          trailing: Icon(
            status == 'accepted'
                ? Icons.check_circle
                : status == 'declined'
                    ? Icons.cancel
                    : Icons.schedule,
            color: status == 'accepted'
                ? Colors.green
                : status == 'declined'
                    ? Colors.red
                    : Colors.orange,
          ),
        );
      },
    );
  }

  void _cancelEvent(BuildContext context) async {
    if (eventId == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Event'),
          content: const Text('Are you sure you want to cancel this event? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes, Cancel'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
      showSnackBar('Event cancelled successfully');
      Navigator.of(context).pop();
    } catch (e) {
      showSnackBar('Error cancelling event: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.75,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  Text(
                    place['name'],
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  if (!isEventPlace) ...[
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${place['rating']} (${place['user_ratings_total']} reviews)',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${place['vicinity']}',
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    if (place['opening_hours'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.blue, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            place['opening_hours']['open_now'] ? 'Open Now' : 'Closed',
                            style: TextStyle(
                              fontSize: 16,
                              color: place['opening_hours']['open_now'] ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (place['types'] != null && place['types'].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: (place['types'] as List<dynamic>)
                            .map((type) => Chip(
                                  label: Text(type.toString().replaceAll('_', ' ')),
                                  backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
                                ))
                            .toList(),
                      ),
                    ]
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openMapsWithDirections(place),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.directions, color: Colors.white),
                          label: const Text('Get Directions', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isEventPlace || (isEventPlace && eventId != null))
                        StreamBuilder<DocumentSnapshot>(
                          stream: isEventPlace
                              ? FirebaseFirestore.instance.collection('events').doc(eventId).snapshots()
                              : null,
                          builder: (context, snapshot) {
                            if (isEventPlace && (!snapshot.hasData || snapshot.data == null)) {
                              return const SizedBox.shrink();
                            }

                            final currentUser = FirebaseAuth.instance.currentUser;
                            bool isOwner = false;

                            if (isEventPlace && snapshot.data != null) {
                              final eventData = snapshot.data!.data() as Map<String, dynamic>;
                              isOwner = currentUser != null && eventData['owner'] == currentUser.uid;
                            }

                            if (!isEventPlace || (isEventPlace && isOwner)) {
                              return Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _navigateToInviteContacts(context),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.people, color: Colors.white),
                                  label: Text(
                                    isEventPlace ? 'Invite More' : 'Invite Users',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isEventPlace && eventId != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('events').doc(eventId).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();

                        final eventData = snapshot.data!.data() as Map<String, dynamic>;
                        final participants = List<String>.from(eventData['participants'] ?? []);
                        final invitationStatuses = Map<String, String>.from(eventData['invitationStatuses'] ?? {});
                        final scheduledTime = eventData['scheduledTime'] as Timestamp;
                        final ownerId = eventData['owner'] as String;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOwnerTile(ownerId, scheduledTime),
                            const SizedBox(height: 16),
                            Text(
                              'Event Time: ${_formatDateTime(scheduledTime)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Participants:',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...participants.where((userId) => userId != ownerId).map((userId) => _buildParticipantTile(
                                  userId,
                                  invitationStatuses[userId] ?? 'pending',
                                  scheduledTime,
                                )),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            if (isEventPlace && eventId != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('events').doc(eventId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final eventData = snapshot.data!.data() as Map<String, dynamic>;
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final isOwner = currentUser != null && eventData['owner'] == currentUser.uid;

                  if (isOwner) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextButton(
                        onPressed: () => _cancelEvent(context),
                        child: const Text(
                          'Cancel Event',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Not scheduled';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return DateFormat('MMM d, y \'at\' h:mm a').format(date);
    }
    return 'Invalid date';
  }

  void _openMapsWithDirections(Map<String, dynamic> place) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${place['location'].latitude},${place['location'].longitude}&destination_place_id=${place['place_id']}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      showSnackBar('Could not launch maps application');
    }
  }
}
