import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

enum SearchSortOption {
  relevance,
  priceLowHigh,
  priceHighLow,
  fastest,
  popular,
}

enum SearchFilterOption {
  all,
  under300,
  under500,
  emergency,
}

/// Universal live search and filter bar for service discovery (FN-130).
class FixUniversalSearchBar extends StatelessWidget {
  const FixUniversalSearchBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClear,
    required this.activeSort,
    required this.onSortChanged,
    required this.activeFilter,
    required this.onFilterChanged,
    this.hintText = 'Search "tap repair", "fan wiring", "cleaning"...',
    super.key,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final SearchSortOption activeSort;
  final ValueChanged<SearchSortOption> onSortChanged;
  final SearchFilterOption activeFilter;
  final ValueChanged<SearchFilterOption> onFilterChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final hasText = searchController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input Box
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: hasText ? AppColors.primary : AppColors.borderDefault,
              width: hasText ? 1.5 : 1,
            ),
          ),
          child: TextField(
            key: const Key('universal_search_input'),
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.accentGold,
                size: 22,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      key: const Key('universal_search_clear_button'),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Horizontally scrollable Filter & Sort Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Sort dropdown chip
              _buildSortMenu(context),
              const SizedBox(width: AppSpacing.xs),

              // Filter: All
              _buildFilterChip(
                label: 'All Services',
                selected: activeFilter == SearchFilterOption.all,
                onTap: () => onFilterChanged(SearchFilterOption.all),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Filter: Emergency ⚡
              _buildFilterChip(
                label: '⚡ Emergency',
                selected: activeFilter == SearchFilterOption.emergency,
                onTap: () => onFilterChanged(
                  activeFilter == SearchFilterOption.emergency
                      ? SearchFilterOption.all
                      : SearchFilterOption.emergency,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Filter: Under ₹300
              _buildFilterChip(
                label: 'Under ₹300',
                selected: activeFilter == SearchFilterOption.under300,
                onTap: () => onFilterChanged(
                  activeFilter == SearchFilterOption.under300
                      ? SearchFilterOption.all
                      : SearchFilterOption.under300,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Filter: Under ₹500
              _buildFilterChip(
                label: 'Under ₹500',
                selected: activeFilter == SearchFilterOption.under500,
                onTap: () => onFilterChanged(
                  activeFilter == SearchFilterOption.under500
                      ? SearchFilterOption.all
                      : SearchFilterOption.under500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortMenu(BuildContext context) {
    final sortLabel = switch (activeSort) {
      SearchSortOption.priceLowHigh => 'Price: Low → High',
      SearchSortOption.priceHighLow => 'Price: High → Low',
      SearchSortOption.fastest => 'Fastest (<45 min)',
      SearchSortOption.popular => 'Popular First',
      SearchSortOption.relevance => 'Sort by',
    };

    final isCustom = activeSort != SearchSortOption.relevance;

    return PopupMenuButton<SearchSortOption>(
      initialValue: activeSort,
      onSelected: onSortChanged,
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: SearchSortOption.relevance,
          child: Text('Default Relevance', style: TextStyle(color: AppColors.cream)),
        ),
        const PopupMenuItem(
          value: SearchSortOption.priceLowHigh,
          child: Text('Price: Low to High', style: TextStyle(color: AppColors.cream)),
        ),
        const PopupMenuItem(
          value: SearchSortOption.priceHighLow,
          child: Text('Price: High to Low', style: TextStyle(color: AppColors.cream)),
        ),
        const PopupMenuItem(
          value: SearchSortOption.fastest,
          child: Text('Fastest (<45 min)', style: TextStyle(color: AppColors.cream)),
        ),
        const PopupMenuItem(
          value: SearchSortOption.popular,
          child: Text('Most Popular', style: TextStyle(color: AppColors.cream)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isCustom ? AppColors.primarySoft.withValues(alpha: 0.2) : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isCustom ? AppColors.primary : AppColors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: isCustom ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              sortLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.w600 : FontWeight.w500,
                color: isCustom ? AppColors.cream : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderDefault,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.cream : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
