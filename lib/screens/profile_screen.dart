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
  bool _isUpdatingProfileImage = false;
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();
  List<QueryDocumentSnapshot> _pastEvents = [];
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
  }

  void _checkEmailVerification() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      setState(() {
        _isEmailVerified = user.emailVerified;
      });
    }
  }

  Future<void> _sendVerificationEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userIdToFetch = widget.isCurrentUser ? currentUser?.uid : widget.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userIdToFetch).snapshots(),
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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  if (widget.isCurrentUser)
                    IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.black),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const SignInScreen()),
                          (route) => false,
                        );
                      },
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
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
                            onTap: widget.isCurrentUser && !_isUpdatingProfileImage ? _updateProfileImage : null,
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
                      if (widget.isCurrentUser && !_isUpdatingProfileImage)
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
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Past Events',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _buildPastEventsOrVerifyEmail(userIdToFetch),
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

  Widget _buildPastEventsOrVerifyEmail(String? userIdToFetch) {
    if (!widget.isCurrentUser || _isEmailVerified) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('participants', arrayContains: userIdToFetch)
            .orderBy('scheduledTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _pastEvents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final now = DateTime.now();
            _pastEvents = snapshot.data!.docs.where((doc) {
              final event = doc.data() as Map<String, dynamic>;
              final eventTime = (event['scheduledTime'] as Timestamp).toDate();
              return eventTime.isBefore(now);
            }).toList();
          }

          if (_pastEvents.isEmpty) {
            return _buildNoEventsMessage();
          }

          return ListView.builder(
            itemCount: _pastEvents.length,
            itemBuilder: (context, index) {
              final event = _pastEvents[index].data() as Map<String, dynamic>;
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

  Widget _buildNoEventsMessage() {
    return const Center(
      child: Text(
        'No past events',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    final DateTime eventDate = (event['scheduledTime'] as Timestamp).toDate();
    final String formattedDate = DateFormat('MMM d, y \'at\' h:mm a').format(eventDate);

    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event['placeName'] ?? 'Unknown Place',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Event on $formattedDate',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Participants: ${(event['participants'] as List?)?.length ?? 0}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
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
}
