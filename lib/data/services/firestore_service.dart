import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/lost_found_item.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _itemsCollection =>
      _firestore.collection('lost_found_items');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _conversationsCollection =>
      _firestore.collection('conversations');

  Future<List<LostFoundItem>> getItems() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _itemsCollection
        .where('status', isEqualTo: 'active')
        .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);

    documents.sort((
      QueryDocumentSnapshot<Map<String, dynamic>> first,
      QueryDocumentSnapshot<Map<String, dynamic>> second,
    ) {
      final dynamic firstCreatedAt = first.data()['createdAt'];
      final dynamic secondCreatedAt = second.data()['createdAt'];

      if (firstCreatedAt is Timestamp && secondCreatedAt is Timestamp) {
        return secondCreatedAt.compareTo(firstCreatedAt);
      }

      if (firstCreatedAt is Timestamp) {
        return -1;
      }

      if (secondCreatedAt is Timestamp) {
        return 1;
      }

      return 0;
    });

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

  Future<void> saveUserProfile({
    required String userId,
    required String username,
    required String email,
  }) async {
    await _usersCollection.doc(userId).set({
      'username': username.trim(),
      'email': email.trim(),
    }, SetOptions(merge: true));
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

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  String getConversationId({
    required String itemId,
    required String currentUserId,
    required String ownerId,
  }) {
    if (currentUserId == ownerId) {
      throw ArgumentError(
        'The item owner cannot start a conversation with themselves.',
      );
    }

    final List<String> participantIds = <String>[currentUserId, ownerId]
      ..sort();

    return '${itemId}_${participantIds.join('_')}';
  }

  Future<Conversation> createConversation({
    required String itemId,
    required String itemTitle,
    required String currentUserId,
    required String ownerId,
  }) async {
    if (currentUserId == ownerId) {
      throw ArgumentError(
        'The item owner cannot start a conversation with themselves.',
      );
    }

    final String conversationId = getConversationId(
      itemId: itemId,
      currentUserId: currentUserId,
      ownerId: ownerId,
    );

    final DocumentReference<Map<String, dynamic>> conversationReference =
        _conversationsCollection.doc(conversationId);

    final DocumentSnapshot<Map<String, dynamic>> existingConversation =
        await conversationReference.get();

    if (!existingConversation.exists) {
      await conversationReference.set({
        'itemId': itemId,
        'itemTitle': itemTitle.trim(),
        'participantIds': <String>[currentUserId, ownerId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageSenderId': null,
      });
    }

    final DocumentSnapshot<Map<String, dynamic>> conversation =
        await conversationReference.get();

    if (!conversation.exists) {
      throw StateError('Unable to create the conversation.');
    }

    return Conversation.fromFirestore(conversation);
  }

  Future<Conversation?> getConversation({
    required String conversationId,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> document =
        await _conversationsCollection.doc(conversationId).get();

    if (!document.exists) {
      return null;
    }

    return Conversation.fromFirestore(document);
  }

  Future<List<Conversation>> getConversationsForUser(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _conversationsCollection
            .where('participantIds', arrayContains: userId)
            .get();

    final List<Conversation> conversations = snapshot.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              Conversation.fromFirestore(document),
        )
        .toList();

    conversations.sort((Conversation first, Conversation second) {
      final Timestamp? firstUpdatedAt = first.updatedAt;
      final Timestamp? secondUpdatedAt = second.updatedAt;

      if (firstUpdatedAt == null && secondUpdatedAt == null) {
        return 0;
      }

      if (firstUpdatedAt == null) {
        return 1;
      }

      if (secondUpdatedAt == null) {
        return -1;
      }

      return secondUpdatedAt.compareTo(firstUpdatedAt);
    });

    return conversations;
  }

  Stream<List<Conversation>> watchConversationsForUser(String userId) {
    return _conversationsCollection
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<Conversation> conversations = snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                    Conversation.fromFirestore(document),
              )
              .toList();

          conversations.sort((Conversation first, Conversation second) {
            final Timestamp? firstUpdatedAt = first.updatedAt;
            final Timestamp? secondUpdatedAt = second.updatedAt;

            if (firstUpdatedAt == null && secondUpdatedAt == null) {
              return 0;
            }

            if (firstUpdatedAt == null) {
              return 1;
            }

            if (secondUpdatedAt == null) {
              return -1;
            }

            return secondUpdatedAt.compareTo(firstUpdatedAt);
          });

          return conversations;
        });
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _conversationsCollection
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                    ChatMessage.fromFirestore(document),
              )
              .toList();
        });
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final String trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      throw ArgumentError('Message text cannot be empty.');
    }

    if (trimmedText.length > 2000) {
      throw ArgumentError('Message text cannot exceed 2000 characters.');
    }

    final DocumentReference<Map<String, dynamic>> conversationReference =
        _conversationsCollection.doc(conversationId);

    final DocumentReference<Map<String, dynamic>> messageReference =
        conversationReference.collection('messages').doc();

    final WriteBatch batch = _firestore.batch();

    batch.set(messageReference, {
      'senderId': senderId,
      'text': trimmedText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(conversationReference, {
      'lastMessage': trimmedText,
      'lastMessageSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
