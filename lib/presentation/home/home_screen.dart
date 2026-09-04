import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/item_categories.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';
import '../../data/models/conversation.dart';

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
  String? _selectedCategory;
  String _searchQuery = '';

  List<LostFoundItem> _items = <LostFoundItem>[];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  String _userName = 'Student';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
    _loadItems();
    _loadUserName();
  }

  Future<void> _loadItems() async {
    if (_isRefreshing) {
      return;
    }

    final bool isInitialLoad = !_hasLoadedOnce;

    if (mounted) {
      setState(() {
        if (isInitialLoad) {
          _isLoading = true;
        } else {
          _isRefreshing = true;
        }

        _errorMessage = null;
      });
    }

    try {
      final List<LostFoundItem> items = await _firestoreService.getItems();

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
      debugPrint('HOME FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Unable to load items. Please try again.';
      });
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

      final bool matchesCategory =
          _selectedCategory == null || item.category == _selectedCategory;

      final String searchableText = [
        item.title,
        item.description,
        item.category,
        item.location,
      ].join(' ').toLowerCase();

      final bool matchesSearch = searchTerms.every(
        (String term) => searchableText.contains(term),
      );

      return matchesType && matchesStatus && matchesCategory && matchesSearch;
    }).toList();
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedType != null ||
        _selectedStatus != null ||
        _selectedCategory != null;
  }

  int get _activeFilterCount {
    int count = 0;

    if (_selectedType != null) {
      count++;
    }

    if (_selectedStatus != null) {
      count++;
    }

    if (_selectedCategory != null) {
      count++;
    }

    return count;
  }

  void _clearSearchAndFilters() {
    _searchController.clear();

    setState(() {
      _selectedType = null;
      _selectedStatus = null;
      _selectedCategory = null;
    });
  }

  Future<void> _loadUserName() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final String? username = await _firestoreService.getUsername(user.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        _userName = username ?? 'Student';
      });
    } catch (error) {
      debugPrint('HOME USERNAME ERROR: $error');
    }
  }

  Future<void> _showReportMessage() async {
    await Navigator.of(context).pushNamed(AppRoutes.reportItem);

    if (!mounted) {
      return;
    }

    await _loadItems();
  }

  Future<void> _openItemDetails(LostFoundItem item) async {
    await Navigator.of(context)
        .pushNamed(AppRoutes.itemDetails, arguments: item);

    if (!mounted) {
      return;
    }

    await _loadItems();
  }

  Future<void> _openFilters() async {
    LostFoundType? temporaryType = _selectedType;
    LostFoundStatus? temporaryStatus = _selectedStatus;
    String? temporaryCategory = _selectedCategory;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: AppTextStyles.headingMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              temporaryType = null;
                              temporaryStatus = null;
                              temporaryCategory = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Text('Type', style: AppTextStyles.labelMedium),

                    const SizedBox(height: 7),

                    _buildHorizontalFilterRow(
                      children: [
                        _buildModalChoiceChip(
                          label: 'All',
                          icon: Icons.grid_view_rounded,
                          selected: temporaryType == null,
                          onSelected: () {
                            setModalState(() {
                              temporaryType = null;
                            });
                          },
                        ),
                        _buildModalChoiceChip(
                          label: 'Lost',
                          icon: Icons.help_outline_rounded,
                          selected: temporaryType == LostFoundType.lost,
                          onSelected: () {
                            setModalState(() {
                              temporaryType = LostFoundType.lost;
                            });
                          },
                        ),
                        _buildModalChoiceChip(
                          label: 'Found',
                          icon: Icons.check_circle_outline_rounded,
                          selected: temporaryType == LostFoundType.found,
                          onSelected: () {
                            setModalState(() {
                              temporaryType = LostFoundType.found;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text('Status', style: AppTextStyles.labelMedium),

                    const SizedBox(height: 7),

                    _buildHorizontalFilterRow(
                      children: [
                        _buildModalChoiceChip(
                          label: 'All statuses',
                          icon: Icons.layers_outlined,
                          selected: temporaryStatus == null,
                          onSelected: () {
                            setModalState(() {
                              temporaryStatus = null;
                            });
                          },
                        ),
                        _buildModalChoiceChip(
                          label: 'Active',
                          icon: Icons.circle_outlined,
                          selected: temporaryStatus == LostFoundStatus.active,
                          onSelected: () {
                            setModalState(() {
                              temporaryStatus = LostFoundStatus.active;
                            });
                          },
                        ),
                        _buildModalChoiceChip(
                          label: 'Resolved',
                          icon: Icons.check_circle_outline,
                          selected: temporaryStatus == LostFoundStatus.resolved,
                          onSelected: () {
                            setModalState(() {
                              temporaryStatus = LostFoundStatus.resolved;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text('Category', style: AppTextStyles.labelMedium),

                    const SizedBox(height: 7),

                    _buildHorizontalFilterRow(
                      children: [
                        _buildModalChoiceChip(
                          label: 'All',
                          icon: Icons.grid_view_rounded,
                          selected: temporaryCategory == null,
                          onSelected: () {
                            setModalState(() {
                              temporaryCategory = null;
                            });
                          },
                        ),
                        ...ItemCategories.values.map(
                          (String category) => _buildModalChoiceChip(
                            label: category,
                            icon: Icons.category_outlined,
                            selected: temporaryCategory == category,
                            onSelected: () {
                              setModalState(() {
                                temporaryCategory = category;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedType = temporaryType;
                            _selectedStatus = temporaryStatus;
                            _selectedCategory = temporaryCategory;
                          });

                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHorizontalFilterRow({required List<Widget> children}) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (BuildContext context, int index) {
          return children[index];
        },
      ),
    );
  }

  Widget _buildModalChoiceChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  void _removeTypeFilter() {
    setState(() {
      _selectedType = null;
    });
  }

  void _removeStatusFilter() {
    setState(() {
      _selectedStatus = null;
    });
  }

  void _removeCategoryFilter() {
    setState(() {
      _selectedCategory = null;
    });
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
          StreamBuilder<List<Conversation>>(
  stream: FirebaseAuth.instance.currentUser == null
      ? null
      : _firestoreService.watchConversationsForUser(
          FirebaseAuth.instance.currentUser!.uid,
        ),
  builder: (
    BuildContext context,
    AsyncSnapshot<List<Conversation>> snapshot,
  ) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final bool hasUnreadMessages =
        currentUserId != null &&
        (snapshot.data ?? <Conversation>[]).any(
          (Conversation conversation) =>
              conversation.isUnreadFor(currentUserId),
        );

    return IconButton(
      onPressed: () {
        Navigator.of(context).pushNamed(AppRoutes.conversations);
      },
      tooltip: 'Messages',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded),
          if (hasUnreadMessages)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  },
),
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

              const SizedBox(height: 14),

              _buildSearchField(),

              const SizedBox(height: 10),

              _buildCompactFilterBar(),

              if (_hasActiveFilters && _searchQuery.isEmpty) ...[
                const SizedBox(height: 9),
                _buildActiveFilterChips(),
              ],

              const SizedBox(height: 20),

              _buildSectionHeader(items.length),

              const SizedBox(height: 10),

              if (_isLoading)
                _buildLoadingState()
              else if (items.isEmpty && _errorMessage != null)
                _buildErrorState()
              else if (items.isEmpty)
                _buildEmptyState()
              else
                ...items.map(
                  (LostFoundItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemCard(
                      item: item,
                      onTap: () => _openItemDetails(item),
                    ),
                  ),
                ),

              if (_isRefreshing) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Refreshing items...',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],

              if (!_isRefreshing &&
                  _errorMessage != null &&
                  _items.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildRefreshErrorState(),
              ],
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
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back', style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(
                  _userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Find what you lost or help someone find theirs.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
        hintText: 'Search items, locations, categories...',
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

  Widget _buildCompactFilterBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(
              _activeFilterCount == 0
                  ? 'Filters'
                  : 'Filters ($_activeFilterCount)',
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
          ),
        ),

        if (_hasActiveFilters) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: _clearSearchAndFilters,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Clear'),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveFilterChips() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_selectedType != null)
            _buildActiveFilterChip(
              label: _selectedType == LostFoundType.lost ? 'Lost' : 'Found',
              onDeleted: _removeTypeFilter,
            ),

          if (_selectedStatus != null)
            _buildActiveFilterChip(
              label: _selectedStatus == LostFoundStatus.active
                  ? 'Active'
                  : 'Resolved',
              onDeleted: _removeStatusFilter,
            ),

          if (_selectedCategory != null)
            _buildActiveFilterChip(
              label: _selectedCategory!,
              onDeleted: _removeCategoryFilter,
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIconColor: AppColors.textSecondary,
        backgroundColor: AppColors.primarySoft,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildSectionHeader(int itemCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            _hasActiveFilters ? 'Matching Items' : 'Recent Items',
            style: AppTextStyles.headingMedium,
          ),
        ),

        const SizedBox(width: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$itemCount '
            '${itemCount == 1 ? 'item' : 'items'}',
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            Text('Finding recent items...', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
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

            const SizedBox(height: 14),

            Text(
              'Unable to load items',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 7),

            Text(
              _errorMessage ?? 'Something went wrong. Please try again.',
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

  Widget _buildRefreshErrorState() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.error,
              size: 20,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(_errorMessage!, style: AppTextStyles.bodySmall),
            ),

            const SizedBox(width: 6),

            TextButton(onPressed: _loadItems, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
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

            const SizedBox(height: 14),

            Text(
              _hasActiveFilters ? 'No matching items' : 'No items found',
              style: AppTextStyles.headingSmall,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 7),

            Text(
              _hasActiveFilters
                  ? 'Try changing your search or filters.'
                  : 'Items you report will appear here.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),

            if (_hasActiveFilters) ...[
              const SizedBox(height: 16),
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
  const _ItemCard({required this.item, required this.onTap});

  final LostFoundItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isLost = item.type == LostFoundType.lost;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(isLost),

              const SizedBox(width: 11),

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

                        const SizedBox(width: 7),

                        _TypeBadge(label: item.typeLabel, isLost: isLost),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium,
                    ),

                    const SizedBox(height: 9),

                    Wrap(
                      spacing: 9,
                      runSpacing: 5,
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

                    const SizedBox(height: 9),

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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isLost ? AppColors.warningSoft : AppColors.successSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        isLost
            ? Icons.help_outline_rounded
            : Icons.check_circle_outline_rounded,
        color: isLost ? AppColors.warning : AppColors.success,
        size: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isResolved ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 13,
            color: foregroundColor,
          ),

          const SizedBox(width: 5),

          Text(
            isResolved ? 'Resolved' : 'Active',
            style: TextStyle(
              fontSize: 11,
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
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}
