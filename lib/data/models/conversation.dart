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
  });

  final String id;
  final String itemId;
  final String itemTitle;
  final List<String> participantIds;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String lastMessage;
  final String? lastMessageSenderId;

  factory Conversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

    final List<dynamic> rawParticipantIds =
        data['participantIds'] as List<dynamic>? ?? <dynamic>[];

    return Conversation(
      id: document.id,
      itemId: data['itemId'] as String? ?? '',
      itemTitle: data['itemTitle'] as String? ?? '',
      participantIds: rawParticipantIds.whereType<String>().toList(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
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
}
