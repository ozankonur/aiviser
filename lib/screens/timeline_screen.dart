import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:aiviser/services/user_service.dart';
import 'package:shimmer/shimmer.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  _TimelineScreenState createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  final int _eventsPerPage = 20;
  List<String> _followingIds = [];
  final List<DocumentSnapshot> _events = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  bool _isInitialLoad = true;
  String? _error;

  void _showParticipantsBottomSheet(BuildContext context, List<dynamic> participantIds) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'All Participants',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: participantIds.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(participantIds[index]).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            leading: const ShimmerAvatar(),
                            title: Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 16,
                                width: 100,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        final userData = snapshot.data?.data() as Map<String, dynamic>?;
                        final username = userData?['username'] ?? 'Unknown User';
                        final profileImageUrl = userData?['profileImageUrl'] as String?;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                            child: profileImageUrl == null
                                ? Text(
                                    username[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(username),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFollowingIds();
  }

  Future<void> _loadFollowingIds() async {
    try {
      final ids = await _userService.getUserFollowingIds().first;
      if (mounted) {
        setState(() {
          _followingIds = ids;
          print('Following IDs loaded: $_followingIds'); // Debug print
        });
      }
      await _loadMoreEvents();
    } catch (e) {
      print('Error loading following IDs: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load following IDs: $e';
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> _loadMoreEvents() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('Loading events for user $_userId and following $_followingIds'); // Debug print
      Query query = _firestore
          .collection('events')
          .where('participants', arrayContainsAny: [_userId, ..._followingIds])
          .orderBy('scheduledTime', descending: true)
          .limit(_eventsPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();
      print('Query returned ${querySnapshot.docs.length} documents'); // Debug print

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
            _isInitialLoad = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _events.addAll(querySnapshot.docs);
          _lastDocument = querySnapshot.docs.last;
          _isLoading = false;
          _isInitialLoad = false;
          _error = null;
          _hasMore = querySnapshot.docs.length == _eventsPerPage;
        });
      }
    } catch (e) {
      print('Error loading events: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
          _error = 'Failed to load events: $e';
        });
      }
    }
  }

  Future<void> _refreshTimeline() async {
    setState(() {
      _events.clear();
      _lastDocument = null;
      _hasMore = true;
      _error = null;
      _isInitialLoad = true;
    });
    await _loadFollowingIds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _refreshTimeline,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No events to display'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshTimeline,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTimeline,
      child: ListView.builder(
        itemCount: _events.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _events.length) {
            return _buildEventCard(context, _events[index].data() as Map<String, dynamic>);
          } else if (_hasMore) {
            _loadMoreEvents();
            return _buildLoadingIndicator();
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(event['owner']).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ShimmerAvatar();
                }
                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                final username = userData?['username'] ?? 'Unknown User';
                final profileImageUrl = userData?['profileImageUrl'] as String?;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                      child: profileImageUrl == null
                          ? Text(
                              username[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            _getEventStatus(event['scheduledTime'], event['owner'], event['participants']),
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['placeName'],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(event['scheduledTime']),
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildParticipantsSection(event['participants'] as List<dynamic>),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsSection(List<dynamic> participantIds) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showParticipantsBottomSheet(context, participantIds),
            child: SizedBox(
              height: 32,
              child: Stack(
                children: [
                  for (int i = 0; i < participantIds.length.clamp(0, 5); i++)
                    Positioned(
                      left: i * 20.0,
                      child: _buildParticipantAvatar(participantIds[i]),
                    ),
                ],
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => _showParticipantsBottomSheet(context, participantIds),
          icon: Icon(Icons.people, color: Theme.of(context).colorScheme.primary),
          label: Text(
            '${participantIds.length} Participants',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantAvatar(String participantId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(participantId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerAvatar(radius: 16);
        }
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final username = userData?['username'] ?? 'Unknown';
        final profileImageUrl = userData?['profileImageUrl'] as String?;

        return CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.primary,
          backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
          child: profileImageUrl == null
              ? Text(
                  username[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                )
              : null,
        );
      },
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, y \'at\' h:mm a').format(date);
  }

  String _getEventStatus(Timestamp scheduledTime, String ownerId, List<dynamic> participants) {
    final now = DateTime.now();
    final eventTime = scheduledTime.toDate();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isParticipant = participants.contains(currentUserId);

    if (ownerId == currentUserId) {
      if (eventTime.isBefore(now)) {
        return 'You visited';
      } else if (eventTime.difference(now).inHours < 1) {
        return 'You are visiting soon';
      } else {
        return 'You will visit';
      }
    } else if (isParticipant) {
      if (eventTime.isBefore(now)) {
        return 'You visited';
      } else if (eventTime.difference(now).inHours < 1) {
        return 'You are visiting soon';
      } else {
        return 'You will visit';
      }
    } else {
      if (eventTime.isBefore(now)) {
        return 'Event happened';
      } else if (eventTime.difference(now).inHours < 1) {
        return 'Event happening soon';
      } else {
        return 'Upcoming event';
      }
    }
  }
}

class ShimmerAvatar extends StatelessWidget {
  final double radius;

  const ShimmerAvatar({Key? key, this.radius = 24}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
      ),
    );
  }
}
