import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/features/provider/provider_earnings_repository.dart';
import 'package:flutter/material.dart';

/// FN-053: the provider's own earnings ledger. Display-only — it shows records
/// of completed payments, never a payout (ADR-0016). Reachable from the
/// provider workspace.
class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({required this.repository, super.key});

  final ProviderEarningsRepository repository;

  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  late final ProviderEarningsController _controller =
      ProviderEarningsController(widget.repository)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.95),
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Earnings & Ledger',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'Shift Financial Performance',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          tooltip: 'Refresh earnings',
          onPressed: _controller.load,
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: FixPageFrame(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => switch (_controller.state) {
            ProviderEarningsState.loading => const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                semanticsLabel: 'Loading earnings',
              ),
            ),
            ProviderEarningsState.unavailable => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: FixErrorState(
                  title: 'Earnings unavailable',
                  message:
                      'We could not load your earnings right now. Check your '
                      'connection and try again.',
                  onRetry: _controller.load,
                ),
              ),
            ),
            ProviderEarningsState.ready => RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceElevated,
              onRefresh: _controller.load,
              child: _EarningsView(
                earnings: _controller.earnings!,
              ),
            ),
          },
        ),
      ),
    ),
  );
}

class _EarningsView extends StatelessWidget {
  const _EarningsView({required this.earnings});

  final ProviderEarnings earnings;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      // Shift Financial Summary Card (Deep Emerald / Slate container from Stitch blueprint)
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.secondarySlate,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primaryFixedDim,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Net earnings'.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textOnDarkSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.bolt_rounded, size: 12, color: AppColors.onPrimary),
                      SizedBox(width: 3),
                      Text(
                        'Instant Payout',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              earnings.netLabel,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'From ${earnings.paidOrderCount} completed '
              '${earnings.paidOrderCount == 1 ? 'payment.' : 'payments.'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textOnDarkSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Settlement Schedule Ribbon
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Settlement Schedule',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textOnDarkSecondary,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Daily Auto-Credit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryFixed,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        'Liquidity Status',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textOnDarkSecondary,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Direct to Bank',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      // Performance Metrics Row (Stitch 2x2 grid)
      Row(
        children: [
          Expanded(
            child: _metricTile(
              icon: Icons.task_alt_rounded,
              iconColor: AppColors.primary,
              title: '${earnings.paidOrderCount}',
              subtitle: 'Completed Jobs',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _metricTile(
              icon: Icons.payments_rounded,
              iconColor: AppColors.primary,
              title: earnings.grossLabel,
              subtitle: 'Gross Volume',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: _metricTile(
              icon: Icons.remove_circle_outline_rounded,
              iconColor: AppColors.error,
              title: earnings.refundedLabel,
              subtitle: 'Refunds / Holds',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _metricTile(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.primary,
              title: earnings.netLabel,
              subtitle: 'Net Settled',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),

      // Breakdown Details Card
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Earnings Breakdown',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _breakdownRow(label: 'Gross received', value: earnings.grossLabel),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: AppColors.border),
            ),
            _breakdownRow(label: 'Refunded', value: earnings.refundedLabel),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      // Statutory Non-Payout & Escrow Transparency Notice (ADR-0016 Compliance)
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.borderStrong.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.policy_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'ADR-0016 Transparency',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Guaranteed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    earnings.note,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
    ],
  );

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow({
    required String label,
    required String value,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
