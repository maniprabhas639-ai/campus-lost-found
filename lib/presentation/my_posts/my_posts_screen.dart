import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<LostFoundItem> _items = <LostFoundItem>[];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  Future<void> _loadMyPosts() async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'You must be signed in to view your posts.';
      });

      return;
    }

    final bool isInitialLoad = !_hasLoadedOnce;

    setState(() {
      if (isInitialLoad) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }

      _errorMessage = null;
    });

    try {
      final List<LostFoundItem> items =
          await _firestoreService.getItemsByOwner(
        currentUser.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _isLoading = false;
        _isRefreshing = false;
        _hasLoadedOnce = true;
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('MY POSTS FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Unable to load your posts. Please try again.';
      });
    }
  }

  Future<void> _openItemDetails(LostFoundItem item) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.itemDetails,
      arguments: item,
    );

    if (!mounted) {
      return;
    }

    await _loadMyPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMyPosts,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Loading your posts...',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty && _errorMessage != null) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _items.length + 1 + (_isRefreshing ? 1 : 0),
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _buildHeader();
        }

        final int itemIndex = index - 1;

        if (itemIndex == _items.length) {
          return _buildRefreshingState();
        }

        final LostFoundItem item = _items[itemIndex];

        return _buildItemCard(item);
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 27,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your reported items',
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _items.isEmpty
                      ? 'Items you report will appear here.'
                      : '${_items.length} ${_items.length == 1 ? 'item' : 'items'} reported',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(LostFoundItem item) {
    final bool isLost = item.type == LostFoundType.lost;
    final bool isResolved = item.status == LostFoundStatus.resolved;

    final Color typeColor =
        isLost ? AppColors.warning : AppColors.success;

    final Color typeBackground =
        isLost ? AppColors.warningSoft : AppColors.successSoft;

    final Color statusColor =
        isResolved ? AppColors.success : AppColors.warning;

    final Color statusBackground =
        isResolved ? AppColors.successSoft : AppColors.warningSoft;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openItemDetails(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: typeBackground,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      isLost
                          ? Icons.help_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      color: typeColor,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headingSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTypeBadge(
                    label: item.typeLabel,
                    color: typeColor,
                    backgroundColor: typeBackground,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildMetaItem(
                    icon: Icons.location_on_outlined,
                    label: item.location,
                  ),
                  _buildMetaItem(
                    icon: Icons.calendar_today_outlined,
                    label: item.date,
                  ),
                  _buildMetaItem(
                    icon: Icons.category_outlined,
                    label: item.category,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatusBadge(
                isResolved: isResolved,
                color: statusColor,
                backgroundColor: statusBackground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge({
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isResolved,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isResolved
                ? Icons.check_circle_outline_rounded
                : Icons.circle_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isResolved ? 'Resolved' : 'Active',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeader(),
        const SizedBox(height: 70),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.errorSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 31,
              color: AppColors.error,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Unable to load your posts',
          textAlign: TextAlign.center,
          style: AppTextStyles.headingMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Something went wrong. Please try again.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: _loadMyPosts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildHeader(),
        const SizedBox(height: 70),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 34,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'No posts yet',
          textAlign: TextAlign.center,
          style: AppTextStyles.headingMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Items you report will appear here.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildRefreshingState() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Refreshing your posts...',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}