import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
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
  LostFoundStatus? _selectedStatus;
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
      final List<LostFoundItem> items = await _firestoreService.getItems();

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
    final List<String> searchTerms = _searchQuery
        .split(RegExp(r'\s+'))
        .where((String term) => term.isNotEmpty)
        .toList();

    return _items.where((LostFoundItem item) {
      final bool matchesType =
          _selectedType == null || item.type == _selectedType;

      final bool matchesStatus =
          _selectedStatus == null || item.status == _selectedStatus;

      final String searchableText = [
        item.title,
        item.description,
        item.category,
        item.location,
      ].join(' ').toLowerCase();

      final bool matchesSearch = searchTerms.every(
        (String term) => searchableText.contains(term),
      );

      return matchesType && matchesStatus && matchesSearch;
    }).toList();
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedType != null ||
        _selectedStatus != null;
  }

  void _clearSearchAndFilters() {
    _searchController.clear();

    setState(() {
      _selectedType = null;
      _selectedStatus = null;
    });
  }

  String get _userName {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    final String? email = user?.email;

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Student';
  }

  Future<void> _showReportMessage() async {
    await Navigator.of(context).pushNamed(AppRoutes.reportItem);

    if (!mounted) {
      return;
    }

    await _loadItems();
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
            tooltip: 'My Posts',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.myPosts);
            },
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
            icon: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadItems,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 20),
              _buildSearchField(),
              const SizedBox(height: 20),
              _buildFilterSection(),
              const SizedBox(height: 28),
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
        label: const Text(
          'Report Item',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  _userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Find what you lost or help someone find theirs.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search title, description, location...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.clear_rounded),
              )
            : null,
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.tune_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 7),
            Text('Filter items', style: AppTextStyles.labelMedium),
            if (_hasActiveFilters) ...[
              const Spacer(),
              TextButton(
                onPressed: _clearSearchAndFilters,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text('Type', style: AppTextStyles.bodySmall),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              label: 'All',
              icon: Icons.grid_view_rounded,
              selected: _selectedType == null,
              onSelected: (_) {
                setState(() {
                  _selectedType = null;
                });
              },
            ),
            _buildFilterChip(
              label: 'Lost',
              icon: Icons.help_outline_rounded,
              selected: _selectedType == LostFoundType.lost,
              onSelected: (_) {
                setState(() {
                  _selectedType = LostFoundType.lost;
                });
              },
            ),
            _buildFilterChip(
              label: 'Found',
              icon: Icons.check_circle_outline_rounded,
              selected: _selectedType == LostFoundType.found,
              onSelected: (_) {
                setState(() {
                  _selectedType = LostFoundType.found;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Status', style: AppTextStyles.bodySmall),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusFilterChip(
              label: 'All statuses',
              icon: Icons.layers_outlined,
              selected: _selectedStatus == null,
              onSelected: (_) {
                setState(() {
                  _selectedStatus = null;
                });
              },
            ),
            _buildStatusFilterChip(
              label: 'Active',
              icon: Icons.circle_outlined,
              selected: _selectedStatus == LostFoundStatus.active,
              onSelected: (_) {
                setState(() {
                  _selectedStatus = LostFoundStatus.active;
                });
              },
            ),
            _buildStatusFilterChip(
              label: 'Resolved',
              icon: Icons.check_circle_outline,
              selected: _selectedStatus == LostFoundStatus.resolved,
              onSelected: (_) {
                setState(() {
                  _selectedStatus = LostFoundStatus.resolved;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }

  Widget _buildStatusFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }

  Widget _buildSectionHeader(int itemCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            _hasActiveFilters ? 'Matching Items' : 'Recent Items',
            style: AppTextStyles.headingMedium,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text('Loading items...', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load items',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong. Please try again.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _hasActiveFilters
                    ? AppColors.primarySoft
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _hasActiveFilters
                    ? Icons.filter_alt_off_rounded
                    : Icons.inventory_2_outlined,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _hasActiveFilters ? 'No matching items' : 'No items found',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters
                  ? 'Try changing your search or filters.'
                  : 'Items you report will appear here.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: _clearSearchAndFilters,
                child: const Text('Clear Search & Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final LostFoundItem item;

  @override
  Widget build(BuildContext context) {
    final bool isLost = item.type == LostFoundType.lost;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context)
              .pushNamed(AppRoutes.itemDetails, arguments: item);
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headingSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TypeBadge(label: item.typeLabel, isLost: isLost),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 12,
                      runSpacing: 7,
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
                    const SizedBox(height: 12),
                    _ResolutionBadge(status: item.status),
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
        color: isLost ? AppColors.warningSoft : AppColors.successSoft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        isLost
            ? Icons.help_outline_rounded
            : Icons.check_circle_outline_rounded,
        color: isLost ? AppColors.warning : AppColors.success,
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.isLost});

  final String label;
  final bool isLost;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isLost
        ? AppColors.warningSoft
        : AppColors.successSoft;

    final Color textColor = isLost ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _ResolutionBadge extends StatelessWidget {
  const _ResolutionBadge({required this.status});

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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isResolved ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 14,
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
