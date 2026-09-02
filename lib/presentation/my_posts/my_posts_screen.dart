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
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
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
      itemCount: _items.length + (_isRefreshing ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        if (index == _items.length) {
          return _buildRefreshingState();
        }

        final LostFoundItem item = _items[index];

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              child: Icon(
                item.type == LostFoundType.lost
                    ? Icons.help_outline
                    : Icons.check_circle_outline,
              ),
            ),
            title: Text(
              item.title,
              style: AppTextStyles.headingMedium,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${item.typeLabel} • ${item.category}\n'
                '${item.location} • ${item.date}',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openItemDetails(item),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.cloud_off_outlined,
            size: 30,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton(
            onPressed: _loadMyPosts,
            child: const Text('Try Again'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(
          Icons.inventory_2_outlined,
          size: 64,
        ),
        const SizedBox(height: 16),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
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
      ),
    );
  }
}