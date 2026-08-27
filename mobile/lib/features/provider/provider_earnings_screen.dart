import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
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
    appBar: AppBar(title: const Text('Earnings')),
    body: SafeArea(
      top: false,
      child: FixPageFrame(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => switch (_controller.state) {
            ProviderEarningsState.loading => const Center(
              child: CircularProgressIndicator(
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
            ProviderEarningsState.ready => _EarningsView(
              earnings: _controller.earnings!,
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
    padding: const EdgeInsets.all(AppSpacing.pagePadding),
    children: [
      const FixPageHeader(
        eyebrow: 'EARNINGS',
        title: 'Your earnings',
        description: 'A record of completed payments on FixNow.',
      ),
      const SizedBox(height: AppSpacing.lg),
      FixCard(
        tone: FixCardTone.elevated,
        semanticLabel: 'Net earnings ${earnings.netLabel}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net earnings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textOnLightSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              earnings.netLabel,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.textOnLightPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'From ${earnings.paidOrderCount} completed '
              '${earnings.paidOrderCount == 1 ? 'payment' : 'payments'}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textOnLightSecondary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FixCard(
        semanticLabel: 'Earnings breakdown',
        child: Column(
          children: [
            _Row(label: 'Gross received', value: earnings.grossLabel),
            const Divider(height: AppSpacing.lg),
            _Row(label: 'Refunded', value: earnings.refundedLabel),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FixCard(
        tone: FixCardTone.secondary,
        semanticLabel: 'Payout availability note',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                earnings.note,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyLarge),
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textOnSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
