import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.participantIds,
    this.createdAt,
    this.updatedAt,
    this.lastMessage = '',
    this.lastMessageSenderId,
    this.readBy = const <String>[],
  });

  final String id;
  final String itemId;
  final String itemTitle;
  final List<String> participantIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String lastMessage;
  final String? lastMessageSenderId;
  final List<String> readBy;

  factory Conversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

    final List<dynamic> rawParticipantIds =
        data['participantIds'] as List<dynamic>? ?? <dynamic>[];

    final List<dynamic> rawReadBy =
        data['readBy'] as List<dynamic>? ?? <dynamic>[];

    return Conversation(
      id: document.id,
      itemId: data['itemId'] as String? ?? '',
      itemTitle: data['itemTitle'] as String? ?? '',
      participantIds: rawParticipantIds.whereType<String>().toList(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      readBy: rawReadBy.whereType<String>().toList(),
    );
  }

  String? getOtherParticipantId(String currentUserId) {
    for (final String participantId in participantIds) {
      if (participantId != currentUserId) {
        return participantId;
      }
    }

    return null;
  }

  bool isUnreadFor(String userId) {
    if (lastMessage.trim().isEmpty || lastMessageSenderId == null) {
      return false;
    }

    if (lastMessageSenderId == userId) {
      return false;
    }

    return !readBy.contains(userId);
  }
}
