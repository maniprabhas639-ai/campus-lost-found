import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lost_found_item.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('lost_found_items');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Future<List<LostFoundItem>> getItems() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _itemsCollection
            .where('status', isEqualTo: 'active')
            .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
      snapshot.docs,
    );

    documents.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>> first,
        QueryDocumentSnapshot<Map<String, dynamic>> second,
      ) {
        final dynamic firstCreatedAt = first.data()['createdAt'];
        final dynamic secondCreatedAt = second.data()['createdAt'];

        if (firstCreatedAt is Timestamp &&
            secondCreatedAt is Timestamp) {
          return secondCreatedAt.compareTo(firstCreatedAt);
        }

        if (firstCreatedAt is Timestamp) {
          return -1;
        }

        if (secondCreatedAt is Timestamp) {
          return 1;
        }

        return 0;
      },
    );

    return documents
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              LostFoundItem.fromFirestore(document),
        )
        .toList();
  }

  Future<LostFoundItem?> getItemById(String itemId) async {
    final DocumentSnapshot<Map<String, dynamic>> document =
        await _itemsCollection.doc(itemId).get();

    if (!document.exists) {
      return null;
    }

    return LostFoundItem.fromFirestore(document);
  }

  Future<List<LostFoundItem>> getItemsByOwner(String ownerId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _itemsCollection
            .where('ownerId', isEqualTo: ownerId)
            .get();

    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              LostFoundItem.fromFirestore(document),
        )
        .toList();
  }

  Future<void> saveUserProfile({
    required String userId,
    required String username,
    required String email,
  }) async {
    await _usersCollection.doc(userId).set(
      {
        'username': username.trim(),
        'email': email.trim(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> getUsername(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> document =
        await _usersCollection.doc(userId).get();

    if (!document.exists) {
      return null;
    }

    final String? username = document.data()?['username'] as String?;

    if (username == null || username.trim().isEmpty) {
      return null;
    }

    return username.trim();
  }

  Future<void> createItem({
    required String title,
    required String description,
    required String category,
    required String type,
    required String location,
    required String date,
    required String ownerId,
    String? imageUrl,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'type': type,
      'location': location.trim(),
      'date': date,
      'ownerId': ownerId,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      data['imageUrl'] = imageUrl.trim();
    }

    await _itemsCollection.add(data);
  }

  Future<void> updateItem({
    required String itemId,
    required String title,
    required String description,
    required String category,
    required String type,
    required String location,
    required String date,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'type': type,
      'location': location.trim(),
      'date': date,
    };

    await _itemsCollection.doc(itemId).update(data);
  }

  Future<void> updateItemStatus({
    required String itemId,
    required LostFoundStatus status,
  }) async {
    await _itemsCollection.doc(itemId).update({
      'status': status == LostFoundStatus.resolved ? 'resolved' : 'active',
    });
  }

  Future<void> deleteItem({required String itemId}) async {
    await _itemsCollection.doc(itemId).delete();
  }
}