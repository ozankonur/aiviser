import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:aiviser/services/user_service.dart';
import 'package:intl/intl.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({Key? key}) : super(key: key);

  @override
  _InvitationsScreenState createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> with SingleTickerProviderStateMixin {
  final InvitationService _invitationService = InvitationService();
  final UserService _userService = UserService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations & Requests', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _userService.getFollowRequests(),
            builder: (context, snapshot) {
              int followRequestsCount = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final followRequests = userData?['followRequests'] as Map<String, dynamic>? ?? {};
                followRequestsCount = followRequests.values.where((v) => v['status'] == 'pending').length;
              }

              return TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Event Invitations'),
                  Tab(
                    child: Stack(
                      children: [
                        const Center(child: Text('Follow Requests')),
                        if (followRequestsCount > 0)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 12,
                                minHeight: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventInvitations(),
          _buildFollowRequests(),
        ],
      ),
    );
  }

  Widget _buildEventInvitations() {
    return StreamBuilder<QuerySnapshot>(
      stream: _invitationService.getPendingInvitations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pending event invitations'));
        }

        final invitations = snapshot.data!.docs;

        return ListView.builder(
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final invitation = invitations[index].data() as Map<String, dynamic>;
            return _buildEventInvitationCard(invitation, invitations[index].id);
          },
        );
      },
    );
  }

  Widget _buildEventInvitationCard(Map<String, dynamic> invitation, String invitationId) {
    final DateTime eventDate = (invitation['scheduledTime'] as Timestamp).toDate();
    final String formattedDate = DateFormat('MMM d, y \'at\' h:mm a').format(eventDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(invitation['placeName'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('When: $formattedDate'),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(invitation['owner']).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Organizer: Loading...');
                }
                if (snapshot.hasData && snapshot.data!.exists) {
                  final organizer = snapshot.data!.get('username') as String? ?? 'Unknown';
                  return Text('Organized by: $organizer');
                }
                return const Text('Organizer: Unknown');
              },
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _respondToEventInvitation(invitationId, 'accepted'),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _respondToEventInvitation(invitationId, 'declined'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowRequests() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userService.getFollowRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No pending follow requests'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final followRequests = userData?['followRequests'] as Map<String, dynamic>? ?? {};
        final pendingRequests = followRequests.entries.where((e) => e.value['status'] == 'pending').toList();

        if (pendingRequests.isEmpty) {
          return const Center(child: Text('No pending follow requests'));
        }

        return ListView.builder(
          itemCount: pendingRequests.length,
          itemBuilder: (context, index) {
            final request = pendingRequests[index];
            return _buildFollowRequestCard(request.key, request.value);
          },
        );
      },
    );
  }

  Widget _buildFollowRequestCard(String requesterId, Map<String, dynamic> requestData) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(requesterId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('Loading...'),
            ),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final requesterData = snapshot.data!.data() as Map<String, dynamic>;
        final username = requesterData['username'] as String? ?? 'Unknown User';
        final profileImageUrl = requesterData['profileImageUrl'] as String?;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
              child: profileImageUrl == null ? Text(username[0].toUpperCase()) : null,
            ),
            title: Text(username),
            subtitle: Text('Sent ${_formatTimestamp(requestData['timestamp'] as Timestamp)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _respondToFollowRequest(requesterId, true),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _respondToFollowRequest(requesterId, false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _respondToEventInvitation(String eventId, String response) async {
    try {
      await _invitationService.updateInvitationStatus(eventId, response);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation ${response.capitalize()}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating invitation: $e')),
      );
    }
  }

  void _respondToFollowRequest(String requesterId, bool accept) async {
    try {
      if (accept) {
        await _userService.acceptFollowRequest(requesterId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow request accepted')),
        );
      } else {
        await _userService.rejectFollowRequest(requesterId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow request rejected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error responding to follow request: $e')),
      );
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
