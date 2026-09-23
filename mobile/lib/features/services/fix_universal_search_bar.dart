import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:flutter/material.dart';

enum SearchSortOption {
  relevance,
  priceLowHigh,
  priceHighLow,
  fastest,
  popular,
}

enum SearchFilterOption { all, under300, under500, emergency }

/// Universal live search and filter bar for service discovery (FN-130) matching Stitch UI.
class FixUniversalSearchBar extends StatelessWidget {
  const FixUniversalSearchBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClear,
    required this.activeSort,
    required this.onSortChanged,
    required this.activeFilter,
    required this.onFilterChanged,
    this.hintText = 'Search "tap repair", "fan wiring", "switchboard"...',
    this.onAiDiagnose,
    super.key,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final SearchSortOption activeSort;
  final ValueChanged<SearchSortOption> onSortChanged;
  final SearchFilterOption activeFilter;
  final ValueChanged<SearchFilterOption> onFilterChanged;
  final VoidCallback? onAiDiagnose;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final hasText = searchController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input Box (Stitch: surface-container-lowest, rounded-xl, 48px height)
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: hasText ? AppColors.primary : AppColors.borderDefault,
              width: hasText ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            key: const Key('universal_search_input'),
            controller: searchController,
            onChanged: onSearchChanged,
            style: FixNowTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: FixNowTypography.body.copyWith(
                color: AppColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      key: const Key('universal_search_clear_button'),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      onPressed: onClear,
                    )
                  : (onAiDiagnose != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: InkWell(
                              onTap: onAiDiagnose,
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      'Ask AI',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : null),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
