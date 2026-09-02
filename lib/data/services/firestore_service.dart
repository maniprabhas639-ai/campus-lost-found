import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lost_found_item.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('lost_found_items');

  Future<List<LostFoundItem>> getItems() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _itemsCollection.get();

    return snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              LostFoundItem.fromFirestore(document),
        )
        .toList();
  }
}