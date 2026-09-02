import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';

class ItemDetailsScreen extends StatefulWidget {
  const ItemDetailsScreen({
    required this.item,
    super.key,
  });

  final LostFoundItem item;

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  late LostFoundStatus _status;

  bool _isDeleting = false;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();

    _status = widget.item.status;
  }

  Future<void> _updateStatus(LostFoundStatus newStatus) async {
    if (_isDeleting || _isUpdatingStatus || newStatus == _status) {
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _firestoreService.updateItemStatus(
        itemId: widget.item.id,
        status: newStatus,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status = newStatus;
        _isUpdatingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == LostFoundStatus.resolved
                ? 'Item marked as resolved.'
                : 'Item marked as active.',
          ),
        ),
      );
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
          content: Text(
            'Unable to update the item status. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteItem() async {
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
      await _firestoreService.deleteItem(
        itemId: widget.item.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deleted successfully.'),
        ),
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
          content: Text(
            'Unable to delete the item. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LostFoundItem item = widget.item;
    final bool isLost = item.type == LostFoundType.lost;
    final bool isResolved = _status == LostFoundStatus.resolved;

    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwner =
        currentUser != null && currentUser.uid == item.ownerId;

    final bool isBusy = _isDeleting || _isUpdatingStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          if (isOwner) ...[
            IconButton(
              onPressed: isBusy
                  ? null
                  : () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.editItem,
                        arguments: item,
                      );
                    },
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Item',
            ),
            IconButton(
              onPressed: isBusy ? null : _deleteItem,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Delete Item',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return const Icon(
                            Icons.image_not_supported_outlined,
                            size: 64,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.image_outlined,
                      size: 64,
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isLost
                        ? Colors.red.withValues(alpha: 0.12)
                        : Colors.green.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    item.typeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isLost ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  item.category,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusBadge(
              status: _status,
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: AppTextStyles.headingLarge,
            ),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.description_outlined,
              label: 'Description',
              value: item.description,
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: item.location,
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: item.date,
            ),
            if (item.ownerId != null && item.ownerId!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Reported by',
                value: item.ownerId!,
              ),
            ],
            if (isOwner) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item Status',
                        style: AppTextStyles.headingMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isResolved
                            ? 'This item has been resolved.'
                            : 'This item is currently active.',
                        style: AppTextStyles.bodyMedium,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  isResolved
                                      ? Icons.refresh
                                      : Icons.check_circle_outline,
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
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final LostFoundStatus status;

  @override
  Widget build(BuildContext context) {
    final bool isResolved = status == LostFoundStatus.resolved;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isResolved
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.12),
      ),
      child: Text(
        status == LostFoundStatus.resolved ? 'Resolved' : 'Active',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isResolved ? Colors.green : Colors.orange,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}