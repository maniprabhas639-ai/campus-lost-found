import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/conversation.dart';
import '../../data/services/firestore_service.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String? get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String _formatConversationTime(Conversation conversation) {
    final DateTime? dateTime = conversation.updatedAt?.toDate();

    if (dateTime == null) {
      return '';
    }

    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }

    if (difference.inDays < 1) {
      final String hour = dateTime.hour == 0
          ? '12'
          : dateTime.hour > 12
          ? '${dateTime.hour - 12}'
          : '${dateTime.hour}';

      final String minute = dateTime.minute.toString().padLeft(2, '0');
      final String period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: currentUserId == null
            ? _buildSignedOutState()
            : StreamBuilder<List<Conversation>>(
                stream: _firestoreService.watchConversationsForUser(
                  currentUserId,
                ),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<Conversation>> snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return _buildErrorState();
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final List<Conversation> conversations =
                          snapshot.data ?? <Conversation>[];

                      if (conversations.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          return _buildConversationTile(
                            conversations[index],
                            currentUserId,
                          );
                        },
                      );
                    },
              ),
      ),
    );
  }

  Widget _buildConversationTile(
    Conversation conversation,
    String currentUserId,
  ) {
    final String time = _formatConversationTime(conversation);
    final bool hasLastMessage = conversation.lastMessage.trim().isNotEmpty;
    final bool isUnread = conversation.isUnreadFor(currentUserId);

    return Material(
      color: isUnread ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final item = await _firestoreService.getItemById(conversation.itemId);

          if (!mounted) {
            return;
          }

          if (item == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This item is no longer available.'),
              ),
            );
            return;
          }

          Navigator.of(context).pushNamed(
            AppRoutes.chat,
            arguments: <String, dynamic>{
              'item': item,
              'conversationId': conversation.id,
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: isUnread ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.itemTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: isUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasLastMessage
                          ? conversation.lastMessage
                          : 'Start a conversation',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isUnread
                            ? AppColors.textPrimary
                            : hasLastMessage
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                        fontWeight: isUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isUnread
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUnread) ...[
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No messages yet',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'When you message an item owner, your conversations will appear here.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.home,
                  (Route<dynamic> route) => false,
                );
              },
              icon: const Icon(Icons.search_rounded),
              label: const Text('Find an Item'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedOutState() {
    return Center(
      child: Text(
        'Please sign in to view your messages.',
        style: AppTextStyles.bodyMedium,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.warning,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load messages.',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again in a moment.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
