import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/conversation.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.item, this.conversationId, super.key});

  final LostFoundItem item;
  final String? conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Conversation? _conversation;

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  String? get _currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void initState() {
    super.initState();
    _openConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openConversation() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You must be signed in to open this chat.';
      });
      return;
    }

    try {
      final Conversation? existingConversation = widget.conversationId == null
          ? null
          : await _firestoreService.getConversation(
              conversationId: widget.conversationId!,
            );

      final Conversation conversation;

      if (widget.conversationId != null) {
        if (existingConversation == null) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
            _errorMessage = 'This conversation is no longer available.';
          });
          return;
        }

        conversation = existingConversation;
      } else {
        final String? ownerId = widget.item.ownerId;

        if (ownerId == null || ownerId.trim().isEmpty) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
            _errorMessage = 'This item does not have a valid owner.';
          });
          return;
        }

        if (currentUser.uid == ownerId) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
            _errorMessage = 'You cannot message yourself.';
          });
          return;
        }

        conversation = await _firestoreService.createConversation(
          itemId: widget.item.id,
          itemTitle: widget.item.title,
          currentUserId: currentUser.uid,
          ownerId: ownerId,
        );
      }

      await _markConversationAsRead(conversation, currentUser.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        _conversation = conversation;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('OPEN CONVERSATION FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to open this conversation. Please try again.';
      });
    }
  }

  Future<void> _markConversationAsRead(
    Conversation conversation,
    String userId,
  ) async {
    if (!conversation.isUnreadFor(userId)) {
      return;
    }

    try {
      await _firestoreService.markConversationAsRead(
        conversationId: conversation.id,
        userId: userId,
      );
    } catch (error) {
      debugPrint('MARK CONVERSATION AS READ ERROR: $error');
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }

    final String text = _messageController.text.trim();

    if (text.isEmpty) {
      return;
    }

    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message must be 2,000 characters or fewer.'),
        ),
      );
      return;
    }

    final Conversation? conversation = _conversation;
    final String? currentUserId = _currentUserId;

    if (conversation == null || currentUserId == null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _firestoreService.sendMessage(
        conversationId: conversation.id,
        senderId: currentUserId,
        text: text,
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();

      setState(() {
        _isSending = false;
      });

      _scrollToBottom();
    } catch (error) {
      debugPrint('SEND MESSAGE FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send your message. Please try again.'),
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatMessageTime(ChatMessage message) {
    final DateTime? dateTime = message.createdAt?.toDate();

    if (dateTime == null) {
      return '';
    }

    final String hour = dateTime.hour == 0
        ? '12'
        : dateTime.hour > 12
        ? '${dateTime.hour - 12}'
        : '${dateTime.hour}';

    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final Conversation? conversation = _conversation;

    if (conversation == null) {
      return const Center(child: Text('Conversation unavailable.'));
    }

    return Column(
      children: [
        _buildItemHeader(),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _firestoreService.watchMessages(conversation.id),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<ChatMessage>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return _buildMessagesError();
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<ChatMessage> messages =
                      snapshot.data ?? <ChatMessage>[];

                  if (messages.isEmpty) {
                    return _buildEmptyMessages();
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    itemCount: messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildMessageBubble(messages[index]);
                    },
                  );
                },
          ),
        ),
        _buildMessageComposer(),
      ],
    );
  }

  Widget _buildItemHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About this item',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final String? currentUserId = _currentUserId;
    final bool isMine =
        currentUserId != null && message.isSentBy(currentUserId);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (_formatMessageTime(message).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _formatMessageTime(message),
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isSending,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Write a message...',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _sendMessage,
            tooltip: 'Send message',
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Send a message about this item to get started.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Unable to load messages. Please try again.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chat unavailable',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openConversation,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
