import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InvitationsList extends StatelessWidget {
  final InvitationService _invitationService = InvitationService();

  InvitationsList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Your Events',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _invitationService.getUserOldEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No events'));
                }

                final events = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final data = event.data() as Map<String, dynamic>;

                    return EventTile(
                      eventId: event.id,
                      placeName: data['placeName'] ?? 'Unknown Place',
                      ownerId: data['owner'] ?? 'Unknown Owner', // Changed from ownerName to ownerId
                      status: data['invitationStatuses'][FirebaseAuth.instance.currentUser!.uid] ?? 'pending',
                      scheduledTime: data['scheduledTime'] as Timestamp?,
                      onStatusChange: (String newStatus) => _updateEventStatus(event.id, newStatus),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateEventStatus(String eventId, String status) async {
    try {
      await _invitationService.updateInvitationStatus(eventId, status);
    } catch (e) {
      print('Error updating event status: ${e.toString()}');
    }
  }
}

class EventTile extends StatelessWidget {
  final String eventId;
  final String placeName;
  final String ownerId;
  final String status;
  final Timestamp? scheduledTime;
  final Function(String) onStatusChange;

  const EventTile({
    Key? key,
    required this.eventId,
    required this.placeName,
    required this.ownerId,
    required this.status,
    this.scheduledTime,
    required this.onStatusChange,
  }) : super(key: key);

  Future<String> _getOwnerName(String ownerId) async {
    try {
      DocumentSnapshot ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      return ownerDoc.get('username') as String? ?? 'Unknown User';
    } catch (e) {
      print('Error fetching owner name: $e');
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        placeName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: _getOwnerName(ownerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('Organized by: Loading...');
              }
              return Text('Organized by: ${snapshot.data ?? "Unknown User"}');
            },
          ),
          if (scheduledTime != null)
            Text('When: ${DateFormat('MMM d, y \'at\' h:mm a').format(scheduledTime!.toDate())}'),
        ],
      ),
      trailing: _buildStatusDropdown(context),
    );
  }

  Widget _buildStatusDropdown(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _getStatusColor(status).withOpacity(0.1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: status,
          icon: const Icon(Icons.arrow_drop_down),
          iconSize: 24,
          elevation: 16,
          style: TextStyle(color: _getStatusColor(status)),
          onChanged: (String? newValue) {
            if (newValue != null) {
              onStatusChange(newValue);
            }
          },
          items: <String>['pending', 'accepted', 'declined'].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value[0].toUpperCase() + value.substring(1)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
