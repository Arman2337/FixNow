import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:flutter/material.dart';

enum PricingModelType {
  fixed,
  unit,
  quote,
}

/// A transparent, itemized pricing breakdown card conforming to DESIGN.md tokens.
/// Automatically computes statutory GST (18%) and total customer payable amount.
class FixPriceBreakdownCard extends StatefulWidget {
  const FixPriceBreakdownCard({
    required this.amountMinor,
    this.currency = 'INR',
    this.modelType = PricingModelType.fixed,
    this.modelLabel,
    this.isExpandable = true,
    this.initiallyExpanded = false,
    super.key,
  });

  /// Base amount in minor units (paise for INR). 0 means price on request.
  final int amountMinor;
  final String currency;
  final PricingModelType modelType;
  final String? modelLabel;
  final bool isExpandable;
  final bool initiallyExpanded;

  @override
  State<FixPriceBreakdownCard> createState() => _FixPriceBreakdownCardState();
}

class _FixPriceBreakdownCardState extends State<FixPriceBreakdownCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  int get _subtotalMinor => widget.amountMinor;
  int get _gstMinor => (_subtotalMinor * 0.18).round();
  int get _totalMinor => _subtotalMinor + _gstMinor;

  String _formatPaise(int minor) {
    if (widget.currency == 'INR') {
      final val = minor / 100;
      return '₹${val.toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';
    }
    return '$minor ${widget.currency}';
  }

  String get _badgeText => widget.modelLabel ?? switch (widget.modelType) {
        PricingModelType.fixed => 'Standard Flat Rate',
        PricingModelType.unit => 'Unit Rate Card',
        PricingModelType.quote => 'On-Site Quote & Inspection',
      };

  @override
  Widget build(BuildContext context) {
    if (widget.amountMinor <= 0) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Price on request — confirmed by the provider after inspection.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textOnLightPrimary,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Model Badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _badgeText,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.isExpandable)
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? 'Hide Details' : 'View Breakdown',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Total Estimate Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  'Estimated Total',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textOnLightPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                _formatPaise(_totalMinor),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          // Collapsible Itemized Lines
          if (_expanded) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1, color: AppColors.borderDefault),
            ),
            _buildLineItem(
              label: 'Standard Service Labour',
              amount: _formatPaise(_subtotalMinor),
            ),
            const SizedBox(height: 4),
            _buildLineItem(
              label: 'Spare Parts / Materials',
              amount: '₹0.00 (On inspection)',
              amountColor: AppColors.textOnSurfaceSecondary,
            ),
            const SizedBox(height: 4),
            _buildLineItem(
              label: 'GST (18% Goods & Services Tax)',
              amount: _formatPaise(_gstMinor),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1, color: AppColors.borderDefault),
            ),
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: AppColors.verified),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Transparent Pricing Guarantee: Final quote confirmed before technician starts work.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textOnSurfaceSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineItem({
    required String label,
    required String amount,
    Color? amountColor,
  }) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textOnSurfaceSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: amountColor ?? AppColors.textOnLightPrimary,
            ),
          ),
        ],
      );
}
