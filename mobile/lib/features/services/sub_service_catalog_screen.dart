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
    this.initialLocation,
    this.onProceedToBooking,
    super.key,
  });

  final ServiceCategory category;
  final BookingLocationFix? initialLocation;

  /// Callback when user confirms cart items to proceed to booking.
  final void Function(
    ServiceCategory updatedCategory,
    String itemizedDescription,
    int calculatedPriceMinor,
    BookingLocationFix? location,
  )? onProceedToBooking;

  @override
  State<SubServiceCatalogScreen> createState() =>
      _SubServiceCatalogScreenState();
}

class _SubServiceCatalogScreenState extends State<SubServiceCatalogScreen> {
  late final ServiceCartController _cart;
  late final List<SubServiceItem> _allSubServices;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cart = ServiceCartController()..addListener(_onCartChanged);
    _allSubServices = SubServiceCatalog.getSubServicesForCategory(
      widget.category.slug,
    );
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
        .where((item) =>
            item.name.toLowerCase().contains(query) ||
            item.description.toLowerCase().contains(query))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.category.name,
          style: AppTypography.heading2.copyWith(color: AppColors.textPrimary, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Main Scrollable List
          ListView(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom: 110, // padding for floating cart bar
            ),
            children: [
              // Hero Guarantee Strip
              _buildCategoryHeroStrip(),

              const SizedBox(height: AppSpacing.md),

              // Search Filter Field
              _buildSearchField(),

              const SizedBox(height: AppSpacing.lg),

              // Section Heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Services Needed',
                    style: AppTypography.title.copyWith(color: AppColors.textPrimary),
                  ),
                  Text(
                    '${_filteredServices.length} options',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Sub-Service Items Cards
              for (final item in _filteredServices) ...[
                _buildSubServiceCard(item),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),

          // Floating Sticky Cart Bar
          if (_cart.isNotEmpty)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: _buildFloatingCartBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeroStrip() {
    final proCount = widget.category.verifiedProCount;
    final rating = widget.category.rating ?? 4.8;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: AppColors.focus, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${proCount > 0 ? proCount : 3} Verified Pros Nearby',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: AppColors.accentGold),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: Colors.white30, fontSize: 12)),
                    const SizedBox(width: 6),
                    const Text('30-Day Work Warranty', style: TextStyle(color: AppColors.success, fontSize: 12)),
                  ],
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
      onChanged: (val) => setState(() => _searchQuery = val),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search tap, leak, unblock, install...',
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSubServiceCard(SubServiceItem item) {
    final qty = _cart.getQuantity(item.id);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: qty > 0 ? AppColors.primary : Colors.white10,
          width: qty > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Tile
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: qty > 0
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(item.icon, color: qty > 0 ? AppColors.focus : Colors.white70, size: 22),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (item.badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          item.badge!,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.formattedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⏱ ${item.formattedDuration}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ),
                      ],
                    ),

                    // Add / Quantity Stepper
                    if (qty == 0)
                      InkWell(
                        onTap: () => _cart.add(item),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: AppColors.focus),
                              SizedBox(width: 4),
                              Text(
                                'ADD',
                                style: TextStyle(
                                  color: AppColors.focus,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _cart.decrement(item),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Icon(Icons.remove_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            InkWell(
                              onTap: () => _cart.add(item),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Icon(Icons.add_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
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

  Widget _buildFloatingCartBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Count & Price
          GestureDetector(
            onTap: _openCartSummarySheet,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_cart.totalItemCount} ${_cart.totalItemCount == 1 ? 'item' : 'items'} • ${_cart.formattedGrandTotal}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'Tap to review breakdown',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right: Button
          InkWell(
            onTap: _handleProceed,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Book Now',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 15),
                ],
              ),
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
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        border: Border(top: BorderSide(color: Colors.white12)),
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cart Summary',
                  style: AppTypography.heading2.copyWith(color: Colors.white, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(color: Colors.white12),

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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            '${item.subService.formattedPrice} × ${item.quantity}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.formattedTotal,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(color: Colors.white12),

            // Totals
            _buildSummaryRow('Items Subtotal', cart.formattedSubtotal),
            _buildSummaryRow('GST (18% Goods & Services Tax)', cart.formattedGst),
            const SizedBox(height: 6),
            _buildSummaryRow('Estimated Total', cart.formattedGrandTotal, isBold: true),

            const SizedBox(height: AppSpacing.lg),

            FixButton(
              label: 'Proceed to Booking (${cart.formattedGrandTotal})',
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
          Text(
            label,
            style: TextStyle(
              color: isBold ? Colors.white : Colors.white70,
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isBold ? AppColors.focus : Colors.white,
              fontSize: isBold ? 16 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
