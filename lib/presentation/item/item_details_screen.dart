import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../data/models/lost_found_item.dart';

class ItemDetailsScreen extends StatelessWidget {
  const ItemDetailsScreen({
    required this.item,
    super.key,
  });

  final LostFoundItem item;

  @override
  Widget build(BuildContext context) {
    final bool isLost = item.type == LostFoundType.lost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
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