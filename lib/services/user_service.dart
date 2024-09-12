import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> updateProfileImage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    // Resize and compress the image
    final originalImage = img.decodeImage(imageFile.readAsBytesSync())!;
    final resizedImage = img.copyResize(originalImage, width: 300);
    final compressedImage = img.encodeJpg(resizedImage, quality: 85);

    // Upload the compressed image to Firebase Storage
    final storageRef = _storage.ref().child('profile_images/${user.uid}.jpg');
    await storageRef.putData(compressedImage);

    // Get the download URL of the uploaded image
    final downloadUrl = await storageRef.getDownloadURL();

    // Update the user's profile in Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'profileImageUrl': downloadUrl,
    });
  }

  Stream<List<String>> getUserFollowingIds() {
    final userId = _auth.currentUser?.uid;
    print('User ID: $userId');
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore.collection('users').doc(userId).snapshots().map((snapshot) {
      final userData = snapshot.data();
      if (userData != null && userData['following'] is List) {
        return List<String>.from(userData['following']);
      }
      return <String>[];
    });
  }

  Future<String?> getProfileImageUrl(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.data()?['profileImageUrl'];
  }

  Future<void> unfollowUser(String userIdToUnfollow) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');

    final batch = _firestore.batch();

    batch.update(_firestore.collection('users').doc(currentUser.uid), {
      'following': FieldValue.arrayRemove([userIdToUnfollow]),
      'sentFollowRequests.$userIdToUnfollow': FieldValue.delete(),
    });
    batch.update(_firestore.collection('users').doc(userIdToUnfollow), {
      'followers': FieldValue.arrayRemove([currentUser.uid]),
      'followRequests.${currentUser.uid}': FieldValue.delete(),
    });

    await batch.commit();
  }

  Future<void> acceptFollowRequest(String requesterId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');

    WriteBatch batch = _firestore.batch();

    // Update the requester's following list and remove their sent request
    batch.update(_firestore.collection('users').doc(requesterId), {
      'following': FieldValue.arrayUnion([currentUser.uid]),
      'sentFollowRequests.${currentUser.uid}': FieldValue.delete(),
    });

    // Update the current user's followers list and remove the follow request
    batch.update(_firestore.collection('users').doc(currentUser.uid), {
      'followers': FieldValue.arrayUnion([requesterId]),
      'followRequests.$requesterId': FieldValue.delete()
    });

    await batch.commit();
  }

  Future<void> rejectFollowRequest(String requesterId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');

    WriteBatch batch = _firestore.batch();

    // Remove the follow request from the current user's document
    batch.update(
        _firestore.collection('users').doc(currentUser.uid), {'followRequests.$requesterId': FieldValue.delete()});

    // Remove the sent request from the requester's document
    batch.update(_firestore.collection('users').doc(requesterId),
        {'sentFollowRequests.${currentUser.uid}': FieldValue.delete()});

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getUserFollowersPaginated({
    int limit = 10,
    String? lastUserId,
    String? searchQuery,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    Query query = _firestore
        .collection('users')
        .where('following', arrayContains: currentUser.uid)
        .orderBy('username')
        .limit(limit);

    if (lastUserId != null) {
      final lastUserDoc = await _firestore.collection('users').doc(lastUserId).get();
      query = query.startAfterDocument(lastUserDoc);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .where('usernameLower', isGreaterThanOrEqualTo: searchQuery.toLowerCase())
          .where('usernameLower', isLessThan: searchQuery.toLowerCase() + 'z');
    }

    final querySnapshot = await query.get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'username': data['username'] ?? 'No username',
        'email': data['email'] ?? 'No email',
        'profileImageUrl': data['profileImageUrl'],
        'isInvited': false,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getUserFollowers() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final followers = List<String>.from(userDoc.data()?['followers'] ?? []);

    List<Map<String, dynamic>> followerDetails = [];

    for (String followerId in followers) {
      final followerDoc = await _firestore.collection('users').doc(followerId).get();
      final followerData = followerDoc.data();

      if (followerData != null) {
        followerDetails.add({
          'id': followerId,
          'username': followerData['username'] ?? 'No username',
          'email': followerData['email'] ?? 'No email',
          'profileImageUrl': followerData['profileImageUrl'],
          'isInvited': false,
        });
      }
    }

    return followerDetails;
  }

  Future<List<Map<String, dynamic>>> searchUsersByName(String query) async {
    query = query.toLowerCase();
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: query)
          .where('usernameLower', isLessThan: query + 'z')
          .get();

      // Get the current user's document to check for sent follow requests
      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final sentRequests = (currentUserDoc.data()?['sentFollowRequests'] as Map<String, dynamic>?) ?? {};

      return await Future.wait(result.docs.where((doc) => doc.id != currentUser.uid).map((doc) async {
        final data = doc.data() as Map<String, dynamic>;
        final targetUserDoc = await _firestore.collection('users').doc(doc.id).get();
        final targetUserData = targetUserDoc.data() as Map<String, dynamic>;
        final followRequests = targetUserData['followRequests'] as Map<String, dynamic>? ?? {};

        String followStatus = 'not_following';
        if ((data['followers'] as List<dynamic>?)?.contains(currentUser.uid) ?? false) {
          followStatus = 'following';
        } else if (sentRequests.containsKey(doc.id) || followRequests.containsKey(currentUser.uid)) {
          followStatus = 'requested';
        }

        return {
          'id': doc.id,
          'username': data['username'] as String? ?? 'Unknown User',
          'email': data['email'] as String? ?? 'No email',
          'profileImageUrl': data['profileImageUrl'] as String?,
          'isFollowing': followStatus == 'following',
          'followStatus': followStatus,
          'isPrivate': data['isPrivate'] as bool? ?? false,
        };
      }));
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<String> getFollowStatus(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');

    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    final following = List<String>.from(userData['following'] ?? []);
    if (following.contains(targetUserId)) {
      return 'following';
    }

    final sentFollowRequests = userData['sentFollowRequests'] as Map<String, dynamic>? ?? {};
    if (sentFollowRequests.containsKey(targetUserId)) {
      return 'requested';
    }

    return 'not_following';
  }

  Future<String> followUser(String userIdToFollow) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');

    DocumentSnapshot userToFollowDoc = await _firestore.collection('users').doc(userIdToFollow).get();
    Map<String, dynamic> userData = userToFollowDoc.data() as Map<String, dynamic>? ?? {};

    // Check if the user's profile is private, defaulting to false if the field doesn't exist
    bool isPrivate = userData['isPrivate'] ?? false;

    if (isPrivate) {
      // Send a follow request
      await _firestore.collection('users').doc(userIdToFollow).update({
        'followRequests.${currentUser.uid}': {
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        }
      });
      // Add to sent requests for the current user
      await _firestore.collection('users').doc(currentUser.uid).update({
        'sentFollowRequests.$userIdToFollow': {
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        }
      });
      return 'requested';
    } else {
      // Directly follow the user
      await _firestore.collection('users').doc(currentUser.uid).update({
        'following': FieldValue.arrayUnion([userIdToFollow])
      });
      await _firestore.collection('users').doc(userIdToFollow).update({
        'followers': FieldValue.arrayUnion([currentUser.uid])
      });
      return 'following';
    }
  }

  Stream<DocumentSnapshot> getFollowRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');

    return _firestore.collection('users').doc(currentUser.uid).snapshots();
  }

  Future<void> setProfilePrivacy(bool isPrivate) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No user signed in');

    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'isPrivate': isPrivate,
      });

      // If the profile is made private, convert all pending follow requests to "requested" status
      if (isPrivate) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        Map<String, dynamic> followRequests = userDoc.get('followRequests') ?? {};

        Map<String, dynamic> updatedRequests = {};
        followRequests.forEach((key, value) {
          if (value['status'] == 'pending') {
            updatedRequests[key] = {'status': 'requested', 'timestamp': value['timestamp']};
          } else {
            updatedRequests[key] = value;
          }
        });

        await _firestore.collection('users').doc(currentUser.uid).update({'followRequests': updatedRequests});
      }
    } catch (e) {
      throw Exception('Failed to update profile privacy: $e');
    }
  }
}
