import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lost_found_item.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('lost_found_items');

  Future<List<LostFoundItem>> getItems() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _itemsCollection
        .get();

    return snapshot.docs
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
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _itemsCollection
        .where('ownerId', isEqualTo: ownerId)
        .get();

    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              LostFoundItem.fromFirestore(document),
        )
        .toList();
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
