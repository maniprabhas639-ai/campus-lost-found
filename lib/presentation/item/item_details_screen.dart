import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';

class ItemDetailsScreen extends StatefulWidget {
  const ItemDetailsScreen({required this.item, super.key});

  final LostFoundItem item;

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  late LostFoundItem _item;
  late LostFoundStatus _status;

  bool _isDeleting = false;
  bool _isUpdatingStatus = false;
  bool _isRefreshingItem = false;

  @override
  void initState() {
    super.initState();

    _item = widget.item;
    _status = widget.item.status;
  }

  Future<void> _editItem() async {
    if (_isDeleting || _isUpdatingStatus || _isRefreshingItem) {
      return;
    }

    final Object? result = await Navigator.of(context)
        .pushNamed(AppRoutes.editItem, arguments: _item);

    if (result != true || !mounted) {
      return;
    }

    await _reloadItem();
  }

  Future<void> _reloadItem() async {
    if (_isRefreshingItem || _isDeleting || _isUpdatingStatus) {
      return;
    }

    setState(() {
      _isRefreshingItem = true;
    });

    try {
      final LostFoundItem? updatedItem = await _firestoreService.getItemById(
        _item.id,
      );

      if (!mounted) {
        return;
      }

      if (updatedItem == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This item is no longer available.')),
        );

        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _item = updatedItem;
        _status = updatedItem.status;
        _isRefreshingItem = false;
      });
    } catch (error) {
      debugPrint('RELOAD ITEM FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isRefreshingItem = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to refresh the item details. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _updateStatus(LostFoundStatus newStatus) async {
    if (_isDeleting ||
        _isUpdatingStatus ||
        _isRefreshingItem ||
        newStatus == _status) {
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _firestoreService.updateItemStatus(
        itemId: _item.id,
        status: newStatus,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status = newStatus;
        _item = LostFoundItem(
          id: _item.id,
          title: _item.title,
          description: _item.description,
          category: _item.category,
          type: _item.type,
          location: _item.location,
          date: _item.date,
          status: newStatus,
          imageUrl: _item.imageUrl,
          ownerId: _item.ownerId,
        );
        _isUpdatingStatus = false;
      });

      if (newStatus == LostFoundStatus.resolved) {
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item marked as active.')));
    } catch (error) {
      debugPrint('UPDATE ITEM STATUS FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isUpdatingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update the item status. Please try again.'),
        ),
      );
    }
  }

  Future<void> _deleteItem() async {
    if (_isDeleting || _isUpdatingStatus || _isRefreshingItem) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Item?'),
          content: const Text(
            'Are you sure you want to delete this item? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _firestoreService.deleteItem(itemId: _item.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully.')),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('DELETE ITEM FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete the item. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LostFoundItem item = _item;
    final bool isLost = item.type == LostFoundType.lost;
    final bool isResolved = _status == LostFoundStatus.resolved;

    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner = currentUser != null && currentUser.uid == item.ownerId;

    final bool canMessageOwner =
        currentUser != null &&
        !isOwner &&
        item.ownerId != null &&
        item.ownerId!.trim().isNotEmpty &&
        !isResolved;

    final bool isBusy = _isDeleting || _isUpdatingStatus || _isRefreshingItem;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          if (_isRefreshingItem)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (isOwner) ...[
            IconButton(
              onPressed: isBusy ? null : _editItem,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Item',
            ),
            IconButton(
              onPressed: isBusy ? null : _deleteItem,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Delete Item',
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildImageSection(item),
            const SizedBox(height: 18),
            _buildTypeAndCategorySection(item: item, isLost: isLost),
            const SizedBox(height: 14),
            _StatusBadge(status: _status),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: AppTextStyles.headingLarge.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 18),
            _buildDetailsSection(item),
            if (canMessageOwner) ...[
              const SizedBox(height: 20),
              _buildMessageOwnerButton(item),
            ],
            if (isOwner) ...[
              const SizedBox(height: 20),
              _buildStatusCard(isResolved: isResolved, isBusy: isBusy),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(LostFoundItem item) {
    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
          ? Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    );
                  },
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return const _ImagePlaceholder(
                      icon: Icons.image_not_supported_outlined,
                      message: 'Image unavailable',
                    );
                  },
            )
          : const _ImagePlaceholder(
              icon: Icons.image_outlined,
              message: 'No image available',
            ),
    );
  }

  Widget _buildTypeAndCategorySection({
    required LostFoundItem item,
    required bool isLost,
  }) {
    final Color backgroundColor = isLost
        ? AppColors.warningSoft
        : AppColors.successSoft;

    final Color foregroundColor = isLost
        ? AppColors.warning
        : AppColors.success;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLost
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: foregroundColor,
              ),
              const SizedBox(width: 6),
              Text(
                item.typeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(LostFoundItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Item Information', style: AppTextStyles.headingSmall),
        const SizedBox(height: 12),
        _DetailRow(
          icon: Icons.description_outlined,
          label: 'Description',
          value: item.description,
        ),
        const SizedBox(height: 10),
        _DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: item.location,
        ),
        const SizedBox(height: 10),
        _DetailRow(
          icon: Icons.calendar_today_outlined,
          label: 'Date',
          value: item.date,
        ),
        const SizedBox(height: 10),
        const _DetailRow(
          icon: Icons.person_outline,
          label: 'Reported by',
          value: 'Campus user',
        ),
      ],
    );
  }

  Widget _buildMessageOwnerButton(LostFoundItem item) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.chat, arguments: item);
        },
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Message Owner'),
      ),
    );
  }

  Widget _buildStatusCard({required bool isResolved, required bool isBusy}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isResolved
                      ? AppColors.successSoft
                      : AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isResolved
                      ? Icons.check_circle_outline_rounded
                      : Icons.circle_outlined,
                  color: isResolved ? AppColors.success : AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item Status', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 3),
                    Text(
                      isResolved
                          ? 'This item has been resolved.'
                          : 'This item is currently active.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy
                  ? null
                  : () {
                      _updateStatus(
                        isResolved
                            ? LostFoundStatus.active
                            : LostFoundStatus.resolved,
                      );
                    },
              icon: _isUpdatingStatus
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isResolved
                          ? Icons.refresh_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
              label: Text(
                _isUpdatingStatus
                    ? 'Updating...'
                    : isResolved
                    ? 'Mark as Active'
                    : 'Mark as Resolved',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 32, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Text(message, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final LostFoundStatus status;

  @override
  Widget build(BuildContext context) {
    final bool isResolved = status == LostFoundStatus.resolved;

    final Color backgroundColor = isResolved
        ? AppColors.successSoft
        : AppColors.warningSoft;

    final Color foregroundColor = isResolved
        ? AppColors.success
        : AppColors.warning;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isResolved ? Icons.check_circle_outline : Icons.circle_outlined,
              size: 15,
              color: foregroundColor,
            ),
            const SizedBox(width: 5),
            Text(
              isResolved ? 'Resolved' : 'Active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(value, style: AppTextStyles.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
