import 'package:flutter/material.dart';
import 'package:aiviser/screens/sign_in_screen.dart';
import 'package:aiviser/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  final bool isCurrentUser;
  final String userId;

  const ProfileScreen({
    Key? key,
    this.isCurrentUser = true,
    this.userId = '',
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isUpdatingProfileImage = false;
  bool _isEmailVerified = false;
  String _followStatus = 'not_following';
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
    if (!widget.isCurrentUser) {
      _checkFollowStatus();
    }
  }

  void _checkEmailVerification() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      setState(() {
        _isEmailVerified = user.emailVerified;
      });
    }
  }

  void _checkFollowStatus() async {
    if (!widget.isCurrentUser) {
      String status = await _userService.getFollowStatus(widget.userId);
      setState(() {
        _followStatus = status;
      });
    }
  }

  void _showFollowersBottomSheet(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Followers',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('users').doc(userId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(child: Text('No followers'));
                        }
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final followers = List<String>.from(userData['followers'] ?? []);
                        if (followers.isEmpty) {
                          return const Center(child: Text('No followers'));
                        }
                        return ListView.builder(
                          controller: controller,
                          itemCount: followers.length,
                          itemBuilder: (context, index) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(followers[index]).get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const ListTile(
                                    leading: CircularProgressIndicator(),
                                    title: Text('Loading...'),
                                  );
                                }
                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                final followerData = snapshot.data!.data() as Map<String, dynamic>;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: followerData['profileImageUrl'] != null
                                        ? NetworkImage(followerData['profileImageUrl'])
                                        : null,
                                    child: followerData['profileImageUrl'] == null
                                        ? Text(followerData['username'][0].toUpperCase())
                                        : null,
                                  ),
                                  title: Text(followerData['username']),
                                  subtitle: Text(followerData['email']),
                                );
                              },
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
      },
    );
  }

  void _showFollowingBottomSheet(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Following',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('users').doc(userId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(child: Text('Not following anyone'));
                        }
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final following = List<String>.from(userData['following'] ?? []);
                        if (following.isEmpty) {
                          return const Center(child: Text('Not following anyone'));
                        }
                        return ListView.builder(
                          controller: controller,
                          itemCount: following.length,
                          itemBuilder: (context, index) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(following[index]).get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const ListTile(
                                    leading: CircularProgressIndicator(),
                                    title: Text('Loading...'),
                                  );
                                }
                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                final followingData = snapshot.data!.data() as Map<String, dynamic>;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: followingData['profileImageUrl'] != null
                                        ? NetworkImage(followingData['profileImageUrl'])
                                        : null,
                                    child: followingData['profileImageUrl'] == null
                                        ? Text(followingData['username'][0].toUpperCase())
                                        : null,
                                  ),
                                  title: Text(followingData['username']),
                                  subtitle: Text(followingData['email']),
                                );
                              },
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
      },
    );
  }

  Widget _buildFollowButton() {
    bool isEnabled = _followStatus != 'requested';
    Color buttonColor = _followStatus == 'following' ? Colors.grey : Theme.of(context).colorScheme.primary;

    return ElevatedButton(
      onPressed: isEnabled ? _toggleFollow : null,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: buttonColor,
        disabledForegroundColor: Colors.white70,
        disabledBackgroundColor: Colors.grey,
      ),
      child: Text(_getFollowButtonText()),
    );
  }

  Future<void> _toggleFollow() async {
    try {
      if (_followStatus == 'following') {
        await _userService.unfollowUser(widget.userId);
        setState(() {
          _followStatus = 'not_following';
        });
      } else if (_followStatus == 'not_following') {
        String newStatus = await _userService.followUser(widget.userId);
        setState(() {
          _followStatus = newStatus;
        });
      }
      // If status is 'requested', do nothing on button press
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _togglePrivacy() async {
    try {
      await _userService.setProfilePrivacy(!_isPrivate);
      setState(() {
        _isPrivate = !_isPrivate;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userIdToFetch = widget.isCurrentUser ? _auth.currentUser?.uid : widget.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(userIdToFetch).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const SignInScreen()),
              );
            });
            return const SizedBox.shrink();
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final username = userData['username'] ?? 'User';
          final email = userData['email'] ?? 'No email';
          final profileImageUrl = userData['profileImageUrl'];
          final followersCount = (userData['followers'] as List?)?.length ?? 0;
          final followingCount = (userData['following'] as List?)?.length ?? 0;
          _isPrivate = userData['isPrivate'] ?? false;

          final isCurrentUserProfile = widget.isCurrentUser;
          final canViewPrivateInfo = !_isPrivate || isCurrentUserProfile || _followStatus == 'following';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                actions: [
                  if (isCurrentUserProfile)
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.black),
                      onPressed: () async {
                        await _auth.signOut();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const SignInScreen()),
                          (route) => false,
                        );
                      },
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    username,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.white),
                      Positioned(
                        bottom: 80,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: isCurrentUserProfile && !_isUpdatingProfileImage ? _updateProfileImage : null,
                            child: Hero(
                              tag: 'profileButtonHero',
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                ),
                                child: _isUpdatingProfileImage
                                    ? const Center(child: CircularProgressIndicator())
                                    : ClipOval(
                                        child: profileImageUrl != null
                                            ? Image.network(
                                                profileImageUrl,
                                                fit: BoxFit.cover,
                                                width: 100,
                                                height: 100,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Center(
                                                    child: Text(
                                                      username.substring(0, 1).toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 40,
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).colorScheme.secondary,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Center(
                                                child: Text(
                                                  username.substring(0, 1).toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 40,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.secondary,
                                                  ),
                                                ),
                                              ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isCurrentUserProfile && !_isUpdatingProfileImage)
                        Positioned(
                          bottom: 70,
                          right: MediaQuery.of(context).size.width / 2 - 60,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _updateProfileImage,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () => _showFollowersBottomSheet(context, userIdToFetch!),
                            child: Column(
                              children: [
                                Text(
                                  followersCount.toString(),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Text('Followers'),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showFollowingBottomSheet(context, userIdToFetch!),
                            child: Column(
                              children: [
                                Text(
                                  followingCount.toString(),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Text('Following'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (canViewPrivateInfo)
                        Text(
                          email,
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      const SizedBox(height: 16),
                      if (isCurrentUserProfile)
                        ElevatedButton.icon(
                          onPressed: _togglePrivacy,
                          icon: Icon(_isPrivate ? Icons.lock : Icons.lock_open),
                          label: Text(_isPrivate ? 'Make Profile Public' : 'Make Profile Private'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                          ),
                        )
                      else
                        _buildFollowButton(),
                    ],
                  ),
                ),
              ),
              if (canViewPrivateInfo)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Past Events',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _buildPastEventsOrVerifyEmail(userIdToFetch),
                      ],
                    ),
                  ),
                ),
              if (_isPrivate && !isCurrentUserProfile && _followStatus != 'following')
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'This account is private',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Follow this account to see their events and activities',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _getFollowButtonText() {
    switch (_followStatus) {
      case 'following':
        return 'Unfollow';
      case 'requested':
        return 'Requested';
      case 'not_following':
        return 'Follow';
      default:
        return 'Follow';
    }
  }

  Widget _buildPastEventsOrVerifyEmail(String? userIdToFetch) {
    if (!widget.isCurrentUser || _isEmailVerified) {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('events')
            .where('participants', arrayContains: userIdToFetch)
            .orderBy('scheduledTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No past events'));
          }

          final now = DateTime.now();
          final pastEvents = snapshot.data!.docs.where((doc) {
            final event = doc.data() as Map<String, dynamic>;
            final eventTime = (event['scheduledTime'] as Timestamp).toDate();
            return eventTime.isBefore(now);
          }).toList();

          if (pastEvents.isEmpty) {
            return const Center(child: Text('No past events'));
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pastEvents.length,
            itemBuilder: (context, index) {
              final event = pastEvents[index].data() as Map<String, dynamic>;
              return _buildEventCard(context, event);
            },
          );
        },
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Please verify your email to view past events',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendVerificationEmail,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Verify Email'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    final DateTime eventDate = (event['scheduledTime'] as Timestamp).toDate();
    final String formattedDate = DateFormat('MMM d, y \'at\' h:mm a').format(eventDate);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          event['placeName'] ?? 'Unknown Place',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Participants: ${(event['participants'] as List?)?.length ?? 0}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Icon(
          Icons.event_available,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Future<void> _updateProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _isUpdatingProfileImage = true;
      });
      File imageFile = File(image.path);
      try {
        await _userService.updateProfileImage(imageFile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile image: $e')),
        );
      } finally {
        setState(() {
          _isUpdatingProfileImage = false;
        });
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification email: $e')),
        );
      }
    }
  }
}
