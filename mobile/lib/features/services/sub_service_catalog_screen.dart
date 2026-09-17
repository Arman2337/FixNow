import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/sub_service_item.dart';
import 'package:flutter/material.dart';

/// Screen allowing the customer to select specific tasks, adjust quantities,
/// and view real-time cart pricing before proceeding to booking.
class SubServiceCatalogScreen extends StatefulWidget {
  const SubServiceCatalogScreen({
    required this.category,
    required this.api,
    this.initialLocation,
    this.onProceedToBooking,
    super.key,
  });

  final ServiceCategory category;
  final BookingLocationFix? initialLocation;
  final ApiTransport api;

  /// Callback when user confirms cart items to proceed to booking.
  final void Function(
    ServiceCategory updatedCategory,
    String itemizedDescription,
    int calculatedPriceMinor,
    BookingLocationFix? location,
  )?
  onProceedToBooking;

  @override
  State<SubServiceCatalogScreen> createState() =>
      _SubServiceCatalogScreenState();
}

class _SubServiceCatalogScreenState extends State<SubServiceCatalogScreen> {
  late final ServiceCartController _cart;
  List<SubServiceItem> _allSubServices = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cart = ServiceCartController()..addListener(_onCartChanged);
    _loadSubServices();
  }

  Future<void> _loadSubServices() async {
    final repo = SubServiceRepository(widget.api);
    final services = await repo.getSubServicesForCategory(widget.category.slug);
    if (mounted) {
      setState(() {
        _allSubServices = services;
        _isLoading = false;
      });
    }
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    _cart.dispose();
    super.dispose();
  }

  List<SubServiceItem> get _filteredServices {
    if (_searchQuery.trim().isEmpty) return _allSubServices;
    final query = _searchQuery.toLowerCase();
    return _allSubServices
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query),
        )
        .toList();
  }

  void _handleProceed() {
    final description = _cart.isNotEmpty
        ? _cart.summaryDescription
        : 'General ${widget.category.name} service';

    final totalMinor = _cart.isNotEmpty
        ? _cart.grandTotalMinor
        : (widget.category.pricing?.amountMinor ?? 14900);

    // Create updated category reflecting calculated subtotal
    final updatedCategory = ServiceCategory(
      id: widget.category.id,
      name: widget.category.name,
      slug: widget.category.slug,
      description: widget.category.description,
      iconName: widget.category.iconName,
      isEmergency: widget.category.isEmergency,
      pricing: ServiceCategoryPricing(
        amountMinor: totalMinor,
        currency: widget.category.pricing?.currency ?? 'INR',
      ),
      verifiedProCount: widget.category.verifiedProCount,
      onlineProCount: widget.category.onlineProCount,
      rating: widget.category.rating,
      reviewCount: widget.category.reviewCount,
    );

    if (widget.onProceedToBooking != null) {
      widget.onProceedToBooking!(
        updatedCategory,
        description,
        totalMinor,
        widget.initialLocation,
      );
    }
  }

  void _openCartSummarySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CartSummarySheet(
        cart: _cart,
        categoryName: widget.category.name,
        onProceed: () {
          Navigator.of(ctx).pop();
          _handleProceed();
        },
      ),
    );
  }

  bool _showGuideDrawer = false;
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final proCount = widget.category.verifiedProCount;
    final rating = widget.category.rating ?? 4.8;
    final reviewCount = widget.category.reviewCount;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Services Catalog',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Main Scrollable List
          ListView(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
              bottom: 120, // padding for floating cart bar
            ),
            children: [
              // Breadcrumbs
              Row(
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    widget.category.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Stitch Header Card with verified pill & ambient background
              _buildStitchHeaderCard(proCount, rating, reviewCount),

              const SizedBox(height: AppSpacing.sm),

              // Search Bar
              _buildSearchField(),

              const SizedBox(height: AppSpacing.sm),

              // Filter Chips Row
              _buildFilterChipsRow(),

              const SizedBox(height: AppSpacing.sm),

              // 30-Day FixNow Shield Guarantee Strip with Expandable Drawer
              _buildShieldGuaranteeStrip(),

              const SizedBox(height: AppSpacing.md),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else ...[
                // Section Heading
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Services Needed',
                      style: FixNowTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${_filteredServices.length} options',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                // Sub-Service Items Cards
                for (final item in _filteredServices) ...[
                  _buildSubServiceCard(item),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          ),

          // Floating Sticky Cart Bar (Stitch dark surface design)
          if (_cart.isNotEmpty)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _buildFloatingCartBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildStitchHeaderCard(int proCount, double rating, int reviewCount) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -24,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 8,
            child: Icon(
              Icons.water_drop_rounded,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verified Pill Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified Master Professionals',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Title & Description
                Text(
                  widget.category.name,
                  style: FixNowTypography.heading1.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: Text(
                    (widget.category.description != null &&
                            widget.category.description!.isNotEmpty)
                        ? widget.category.description!
                        : 'Instant diagnosis, upfront itemized pricing, and 30-day rework warranty on all replacements.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search tap, flush, mixer, drain leak...',
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    final filters = [
      {'id': 'all', 'label': 'All Services'},
      {'id': 'repair', 'label': 'Repair & Fixes'},
      {'id': 'install', 'label': 'Installation'},
      {'id': 'overhaul', 'label': 'Full Overhaul'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                setState(() => _selectedFilter = f['id']!);
              },
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.borderDefault,
                  ),
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShieldGuaranteeStrip() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), // soft emerald
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.security_update_good_rounded,
                color: Color(0xFF16A34A),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Standard 30-Day FixNow Shield Included',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              InkWell(
                onTap: () =>
                    setState(() => _showGuideDrawer = !_showGuideDrawer),
                child: Row(
                  children: [
                    Text(
                      _showGuideDrawer ? 'Close Guide' : 'Shield Guide',
                      style: const TextStyle(
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    Icon(
                      _showGuideDrawer
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: const Color(0xFF15803D),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Expandable Inclusions / Exclusions Guide Drawer
        if (_showGuideDrawer)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderDefault),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Inclusions: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 11,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'Minor washers, thread seals, machine snaking, calibration & leak check.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cancel_rounded,
                      color: AppColors.error,
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Exclusions: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 11,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'Heavy replacement fixtures, ceramic basin replacements, and concealed masonry breakdown.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubServiceCard(SubServiceItem item) {
    final qty = _cart.getQuantity(item.id);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: qty > 0 ? AppColors.primary : AppColors.borderDefault,
          width: qty > 0 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon/Image Tile with duration pill badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: qty > 0
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              item.icon,
                              color: qty > 0
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 28,
                            ),
                          )
                        : Center(
                            child: Icon(
                              item.icon,
                              color: qty > 0
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 28,
                            ),
                          ),
                  ),
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySlate,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.accentGold,
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          '4.8',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '(1.2k)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        if (item.badge != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.accentGold.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Text(
                              item.badge!,
                              style: const TextStyle(
                                color: Color(0xFF825100),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Bottom Row: Price & Warranty + Add/Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.formattedPrice,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 11,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '30-Day Warranty',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Add Button or Quantity Stepper
              if (qty == 0)
                InkWell(
                  onTap: () => _cart.add(item),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _cart.decrement(item),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Icon(
                            Icons.remove_rounded,
                            color: AppColors.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _cart.add(item),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppRadius.small,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: AppColors.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCartBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondarySlate,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Count Badge + Details
                GestureDetector(
                  onTap: _openCartSummarySheet,
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${_cart.totalItemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_cart.totalItemCount} ${_cart.totalItemCount == 1 ? 'item' : 'items'} selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Government GST (${_cart.formattedGst})',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Grand total & Book Now CTA
                Row(
                  children: [
                    Text(
                      _cart.formattedGrandTotal,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _handleProceed,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Review Cart & Schedule',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal sheet to review itemized cart and proceed
class _CartSummarySheet extends StatelessWidget {
  const _CartSummarySheet({
    required this.cart,
    required this.categoryName,
    required this.onProceed,
  });

  final ServiceCartController cart;
  final String categoryName;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cart Summary',
                  style: FixNowTypography.heading2.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(color: AppColors.borderDefault),

            // Items List
            for (final item in cart.items) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.subService.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${item.subService.formattedPrice} × ${item.quantity}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.formattedTotal,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(color: AppColors.borderDefault),

            // Totals
            _buildSummaryRow('Item Subtotal', cart.formattedSubtotal),
            _buildSummaryRow('Government GST (18%)', cart.formattedGst),
            _buildSummaryRow('Technician Safety & Tool Kit', 'FREE'),
            const SizedBox(height: 6),
            _buildSummaryRow(
              'Estimated Total',
              cart.formattedGrandTotal,
              isBold: true,
            ),

            const SizedBox(height: AppSpacing.lg),

            FixButton(
              label: 'Review Cart & Schedule (${cart.formattedGrandTotal})',
              icon: Icons.arrow_forward_rounded,
              onPressed: onProceed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: isBold ? 14 : 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBold ? AppColors.primary : AppColors.textPrimary,
              fontSize: isBold ? 16 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
