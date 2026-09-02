import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  LostFoundType? _selectedType;
  String _searchQuery = '';

  List<LostFoundItem> _items = <LostFoundItem>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<LostFoundItem> items =
          await _firestoreService.getItems();

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load items. Please try again.';
      });

      debugPrint('HOME FIRESTORE ERROR: $error');
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  List<LostFoundItem> get _filteredItems {
    return _items.where((item) {
      final bool matchesType =
          _selectedType == null || item.type == _selectedType;

      final bool matchesSearch =
          _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery) ||
          item.description.toLowerCase().contains(_searchQuery) ||
          item.category.toLowerCase().contains(_searchQuery) ||
          item.location.toLowerCase().contains(_searchQuery);

      return matchesType && matchesSearch;
    }).toList();
  }

  String get _userName {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user?.displayName != null &&
        user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    final String? email = user?.email;

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Student';
  }

  void _showReportMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report Item will be available in the next phase.'),
      ),
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<LostFoundItem> items = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Lost & Found'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Profile will be added in a later phase.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadItems,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 20),
              _buildSearchField(),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 24),
              _buildSectionHeader(items.length),
              const SizedBox(height: 12),
              if (_isLoading)
                _buildLoadingState()
              else if (_errorMessage != null)
                _buildErrorState()
              else if (items.isEmpty)
                _buildEmptyState()
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ItemCard(item: item),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportMessage,
        icon: const Icon(Icons.add),
        label: const Text('Report Item'),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _userName,
          style: AppTextStyles.headingLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Find what you lost or help someone find theirs.',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search lost or found items',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.clear),
              )
            : null,
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            selected: _selectedType == null,
            onSelected: (_) {
              setState(() {
                _selectedType = null;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Lost',
            selected: _selectedType == LostFoundType.lost,
            onSelected: (_) {
              setState(() {
                _selectedType = LostFoundType.lost;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Found',
            selected: _selectedType == LostFoundType.found,
            onSelected: (_) {
              setState(() {
                _selectedType = LostFoundType.found;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }

  Widget _buildSectionHeader(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Items',
          style: AppTextStyles.headingMedium,
        ),
        Text(
          '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 32,
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load items',
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Something went wrong. Please try again.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadItems,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 40,
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: AppTextStyles.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try another search term or change the filter.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
  });

  final LostFoundItem item;

  @override
  Widget build(BuildContext context) {
    final bool isLost = item.type == LostFoundType.lost;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.title} details coming soon.'),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(isLost),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(
                          label: item.typeLabel,
                          isLost: isLost,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: item.location,
                        ),
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          text: item.date,
                        ),
                        _InfoRow(
                          icon: Icons.category_outlined,
                          text: item.category,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(bool isLost) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Icon(
        isLost ? Icons.help_outline : Icons.check_circle_outline,
        color: AppColors.primary,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.isLost,
  });

  final String label;
  final bool isLost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isLost
              ? AppColors.textPrimary
              : AppColors.primary,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}