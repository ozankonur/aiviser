import 'package:flutter/material.dart';
import 'package:aiviser/services/user_service.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InviteContactsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final DateTime? scheduledTime;
  final String? eventId;

  const InviteContactsScreen({
    Key? key,
    required this.place,
    this.scheduledTime,
    this.eventId,
  }) : super(key: key);

  @override
  _InviteContactsScreenState createState() => _InviteContactsScreenState();
}

class _InviteContactsScreenState extends State<InviteContactsScreen> {
  final UserService _userService = UserService();
  final InvitationService _invitationService = InvitationService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  DateTime? _eventTime;

  @override
  void initState() {
    super.initState();
    _loadEventTime();
  }

  void _loadEventTime() async {
    if (widget.eventId != null) {
      DocumentSnapshot eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      if (eventDoc.exists) {
        setState(() {
          _eventTime = (eventDoc.data() as Map<String, dynamic>)['scheduledTime'].toDate();
        });
      }
    } else {
      _eventTime = widget.scheduledTime;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> results = await _userService.searchUsersByName(query, widget.place['place_id']);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: ${e.toString()}')),
      );
    }
  }

  Future<void> _inviteUser(String userId) async {
    try {
      if (widget.eventId != null) {
        // Add user to existing event
        await _invitationService.addParticipantToEvent(widget.eventId!, userId);
      } else {
        // Create new event
        await _invitationService.createOrUpdateEvent(
          widget.place['place_id'],
          widget.place,
          _eventTime!,
          [userId],
        );
      }
      setState(() {
        _searchResults = _searchResults.map((user) {
          if (user['id'] == userId) {
            user['isInvited'] = true;
          }
          return user;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation sent successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending invitation: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Users'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Column(
        children: [
          if (_eventTime != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                'Event Time: ${DateFormat('MMM d, y \'at\' h:mm a').format(_eventTime!)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _searchUsers,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundImage:
                                user['profileImageUrl'] != null ? NetworkImage(user['profileImageUrl']) : null,
                            child: user['profileImageUrl'] == null ? Text(user['username'][0].toUpperCase()) : null,
                          ),
                          title: Text(
                            user['username'],
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            user['email'],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: user['isInvited']
                              ? Chip(
                                  label: const Text('Invited'),
                                  backgroundColor: Colors.grey.withOpacity(0.2),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                                )
                              : ElevatedButton(
                                  onPressed: () => _inviteUser(user['id']),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text('Invite'),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
