import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<String>> getUserFriendIds() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return List<String>.from(userDoc.data()?['friends'] ?? []);
    }
    return [];
  }

  Future<void> addFriend(String friendId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'friends': FieldValue.arrayUnion([friendId])
      });
      await _firestore.collection('users').doc(friendId).update({
        'friends': FieldValue.arrayUnion([user.uid])
      });
    }
  }

  Future<void> removeFriend(String friendId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'friends': FieldValue.arrayRemove([friendId])
      });
      await _firestore.collection('users').doc(friendId).update({
        'friends': FieldValue.arrayRemove([user.uid])
      });
    }
  }
}