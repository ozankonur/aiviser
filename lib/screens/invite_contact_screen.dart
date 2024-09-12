import 'package:flutter/material.dart';
import 'package:aiviser/services/user_service.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aiviser/screens/profile_screen.dart';

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
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _filteredFollowers = [];
  bool _isLoading = true;
  DateTime? _eventTime;

  @override
  void initState() {
    super.initState();
    _loadEventTime();
    _loadFollowers();
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

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> followers = await _userService.getUserFollowers();
      setState(() {
        _followers = followers;
        _filteredFollowers = followers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading followers: ${e.toString()}')),
      );
    }
  }

  void _filterFollowers(String query) {
    setState(() {
      _filteredFollowers = _followers
          .where((follower) =>
              follower['username'].toLowerCase().contains(query.toLowerCase()) ||
              follower['email'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _inviteFollower(String followerId) async {
    try {
      if (widget.eventId != null) {
        await _invitationService.addParticipantToEvent(widget.eventId!, followerId);
      } else {
        await _invitationService.createOrUpdateEvent(
          widget.place['place_id'],
          widget.place,
          _eventTime!,
          [followerId],
        );
      }
      setState(() {
        _filteredFollowers = _filteredFollowers.map((follower) {
          if (follower['id'] == followerId) {
            follower['isInvited'] = true;
          }
          return follower;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending invitation: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Column(
        children: [
          if (_eventTime != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Event Time: ${DateFormat('MMM d, y \'at\' h:mm a').format(_eventTime!)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search followers',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: _filterFollowers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredFollowers.length,
                    itemBuilder: (context, index) {
                      final follower = _filteredFollowers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              follower['profileImageUrl'] != null ? NetworkImage(follower['profileImageUrl']) : null,
                          child:
                              follower['profileImageUrl'] == null ? Text(follower['username'][0].toUpperCase()) : null,
                        ),
                        title: Text(follower['username']),
                        subtitle: Text(follower['email']),
                        trailing: ElevatedButton(
                          onPressed: follower['isInvited'] ? null : () => _inviteFollower(follower['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: follower['isInvited'] ? Colors.grey : Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(follower['isInvited'] ? 'Invited' : 'Invite', style: const TextStyle(color: Colors.white)),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                isCurrentUser: false,
                                userId: follower['id'],
                              ),
                            ),
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
}
