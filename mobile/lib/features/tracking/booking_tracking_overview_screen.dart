import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:flutter/material.dart';

class BookingTrackingOverviewScreen extends StatelessWidget {
  const BookingTrackingOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.pagePadding),
    children: [
      Semantics(
        header: true,
        child: Text(
          'Bookings',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Track active work and review booking updates.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AppSpacing.xl),
      FixCard(
        semanticLabel: 'No active booking',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.route_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No active booking',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'When a provider is on the way, live status and an estimated arrival time will appear here.',
            ),
          ],
        ),
      ),
    ],
  );
}
