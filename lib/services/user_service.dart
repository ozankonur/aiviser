import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Map<String, dynamic>>> searchUsersByName(String query, String placeId) async {
    query = query.toLowerCase();
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    final QuerySnapshot result = await _firestore.collection('users').get();
    final List<Map<String, dynamic>> searchResults = result.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final username = (data['username'] as String? ?? '').toLowerCase();

          if (RegExp(query).hasMatch(username) && doc.id != currentUser.uid) {
            return {
              'id': doc.id,
              'username': data['username'] ?? 'No username',
              'email': data['email'] ?? 'No email',
              'profileImageUrl': data['profileImageUrl'],
            };
          }
          return null;
        })
        .where((item) => item != null)
        .cast<Map<String, dynamic>>()
        .toList();

    // Check if users have been invited
    final invitedUsers = await _getInvitedUsers(currentUser.uid, placeId);
    for (var user in searchResults) {
      user['isInvited'] = invitedUsers.contains(user['id']);
    }

    return searchResults;
  }

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

  Future<String?> getProfileImageUrl(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.data()?['profileImageUrl'];
  }

  Future<Set<String>> _getInvitedUsers(String currentUserId, String placeId) async {
    final QuerySnapshot invitations = await _firestore
        .collection('invitations')
        .where('senderId', isEqualTo: currentUserId)
        .where('placeId', isEqualTo: placeId)
        .get();

    return invitations.docs.map((doc) => doc['receiverId'] as String).toSet();
  }
}
