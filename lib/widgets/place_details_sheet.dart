import 'dart:io';
import 'package:aiviser/screens/create_event_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aiviser/models/event_image.dart';
import 'package:aiviser/screens/invite_contact_screen.dart';
import 'package:aiviser/services/auth_service.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:aiviser/services/cloudflare_r2_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> place;
  final Function(String) showSnackBar;
  final bool isEventPlace;
  final String? eventId;
  final LatLng? userLocation;

  const PlaceDetailsSheet({
    Key? key,
    required this.place,
    required this.showSnackBar,
    this.isEventPlace = false,
    this.eventId,
    this.userLocation,
  }) : super(key: key);

  @override
  _PlaceDetailsSheetState createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends State<PlaceDetailsSheet> {
  final AuthService _authService = AuthService();
  final InvitationService _invitationService = InvitationService();
  final CloudflareR2Service _r2Service = CloudflareR2Service();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _canUploadImage = false;

  @override
  void initState() {
    super.initState();
    _checkUploadability();
  }

  /*
  void _navigateToInviteContacts(BuildContext context) async {
    bool isVerified = await _authService.isEmailVerified();
    if (!isVerified) {
      widget.showSnackBar('Please verify your email before inviting users.');
      return;
    }

    if (widget.isEventPlace && widget.eventId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InviteContactsScreen(
            place: widget.place,
            eventId: widget.eventId!,
          ),
        ),
      );
    } else {
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
            place: widget.place,
            scheduledTime: selectedDateTime,
          ),
        ),
      );
    }
  }
*/

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(imageQuality: 70, source: source);
      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);
      print('Image picked: ${imageFile.path}');

      setState(() {
        _isUploading = true;
      });

      final String fileName = 'event_${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('Uploading image with filename: $fileName');

      final String imageUrl = await _r2Service.uploadImage(imageFile, fileName);
      print('Image uploaded successfully. URL: $imageUrl');

      await _invitationService.addImageToEvent(
        widget.eventId!,
        imageUrl,
        GeoPoint(widget.userLocation!.latitude, widget.userLocation!.longitude),
      );
      print('Image added to event in Firestore');

      widget.showSnackBar('Image uploaded successfully!');
    } catch (e) {
      print('Error uploading image: $e');
      widget.showSnackBar('Failed to upload image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _checkUploadability() async {
    if (widget.eventId != null) {
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
      final eventData = eventDoc.data();

      if (eventData != null) {
        final eventDate = (eventData['scheduledTime'] as Timestamp).toDate();
        final today = DateTime.now();

        final isToday = eventDate.year == today.year && eventDate.month == today.month && eventDate.day == today.day;

        bool isNearEvent = false;
        if (widget.userLocation != null) {
          isNearEvent = await _invitationService.isUserNearEvent(widget.eventId!, widget.userLocation!);
        }

        setState(() {
          _canUploadImage = isToday && isNearEvent;
        });
      }
    }
  }

  Widget _buildUploadButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _canUploadImage && !_isUploading ? _showImageSourceDialog : null,
      icon: _isUploading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.add_a_photo, size: 18),
      label: Text(_isUploading ? 'Uploading...' : 'Upload'),
      style: ElevatedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        backgroundColor: _canUploadImage ? Theme.of(context).colorScheme.primary : Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildEventImages(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Event Images',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final eventData = snapshot.data!.data() as Map<String, dynamic>?;
                final participants = List<String>.from(eventData?['participants'] ?? []);
                final currentUser = FirebaseAuth.instance.currentUser;

                if (currentUser != null && participants.contains(currentUser.uid)) {
                  return _buildUploadButton(context);
                } else {
                  return const SizedBox.shrink(); // Hide the upload button
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<EventImage>>(
          stream: _invitationService.getEventImages(widget.eventId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('No images uploaded yet.');
            }
            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final image = snapshot.data![index];
                  return _buildImageThumbnail(context, image);
                },
              ),
            );
          },
        ),
      ],
    );
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
    if (widget.eventId == null) return;

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
      await FirebaseFirestore.instance.collection('events').doc(widget.eventId).delete();
      widget.showSnackBar('Event cancelled successfully');
      Navigator.of(context).pop();
    } catch (e) {
      widget.showSnackBar('Error cancelling event: $e');
    }
  }

  Future<void> _deleteImage(EventImage image) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('Are you sure you want to delete this image?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _invitationService.deleteEventImage(widget.eventId!, image.id);
        widget.showSnackBar('Image deleted successfully');
      } catch (e) {
        widget.showSnackBar('Failed to delete image: $e');
      }
    }
  }

  Widget _buildImageThumbnail(BuildContext context, EventImage image) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showFullScreenImage(context, image),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                image.imageUrl,
                width: 100,
                height: 120,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 100,
                    height: 120,
                    color: Colors.grey[300],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    width: 100,
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  );
                },
              ),
            ),
          ),
          if (image.userId == FirebaseAuth.instance.currentUser?.uid)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _deleteImage(image),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, EventImage image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  image.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.error, color: Colors.white));
                  },
                ),
              ),
              // Close button
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // User info and timestamp
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(image.userId).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final username = userData['username'] ?? 'Unknown User';
                        final profileImageUrl = userData['profileImageUrl'];
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                              child: profileImageUrl == null ? Text(username[0].toUpperCase()) : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              username,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().add_jm().format(image.timestamp),
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
      widget.showSnackBar('Could not launch maps application');
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
        child: ListView(
          controller: controller,
          children: [
            Text(
              widget.place['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (!widget.isEventPlace) ...[
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.place['rating']} (${widget.place['user_ratings_total']} reviews)',
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
                      '${widget.place['vicinity']}',
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              if (widget.place['opening_hours'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      widget.place['opening_hours']['open_now'] ? 'Open Now' : 'Closed',
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.place['opening_hours']['open_now'] ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.place['types'] != null && widget.place['types'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (widget.place['types'] as List<dynamic>)
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
                    onPressed: () => _openMapsWithDirections(widget.place),
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
                if (!widget.isEventPlace || (widget.isEventPlace && widget.eventId != null))
                  StreamBuilder<DocumentSnapshot>(
                    stream: widget.isEventPlace
                        ? FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots()
                        : null,
                    builder: (context, snapshot) {
                      if (widget.isEventPlace && (!snapshot.hasData || snapshot.data == null)) {
                        return const SizedBox.shrink();
                      }

                      final currentUser = FirebaseAuth.instance.currentUser;
                      bool isOwner = false;

                      if (widget.isEventPlace && snapshot.data != null) {
                        final eventData = snapshot.data!.data() as Map<String, dynamic>;
                        isOwner = currentUser != null && eventData['owner'] == currentUser.uid;
                      }

                      if (!widget.isEventPlace || (widget.isEventPlace && isOwner)) {
                        return Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToCreateEvent(context),
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
                              widget.isEventPlace ? 'Invite More' : 'Invite Users',
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
            const SizedBox(height: 24),
            if (widget.isEventPlace && widget.eventId != null) ...[
              _buildEventImages(context),
              const SizedBox(height: 24),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
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
            if (widget.isEventPlace && widget.eventId != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
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

  void _navigateToCreateEvent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(location: widget.place['location']),
      ),
    );
  }
}
