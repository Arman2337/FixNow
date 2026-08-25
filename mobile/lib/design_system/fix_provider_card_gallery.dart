import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_provider_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';

/// A standalone preview of [FixProviderCard] across its three states, with a
/// reduce-motion toggle. This is a design-system harness, not a product screen:
/// it is not wired into navigation. Push to it from anywhere to review the
/// card on a real device, e.g.
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute<void>(builder: (_) => const FixProviderCardGallery()),
/// );
/// ```
class FixProviderCardGallery extends StatefulWidget {
  const FixProviderCardGallery({super.key});

  @override
  State<FixProviderCardGallery> createState() => _FixProviderCardGalleryState();
}

class _FixProviderCardGalleryState extends State<FixProviderCardGallery> {
  FixProviderCardState _state = FixProviderCardState.enRoute;
  bool _reduceMotion = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('FixProviderCard'),
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SegmentedButton<FixProviderCardState>(
              segments: const [
                ButtonSegment(
                  value: FixProviderCardState.finding,
                  label: Text('Finding'),
                ),
                ButtonSegment(
                  value: FixProviderCardState.enRoute,
                  label: Text('En route'),
                ),
                ButtonSegment(
                  value: FixProviderCardState.arrived,
                  label: Text('Arrived'),
                ),
              ],
              selected: {_state},
              onSelectionChanged: (selection) =>
                  setState(() => _state = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reduceMotion,
              onChanged: (value) => setState(() => _reduceMotion = value),
              title: Text(
                'Reduce motion',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Simulates the OS accessibility setting',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Overriding disableAnimations lets the toggle exercise the exact
            // reduce-motion path the fix_motion primitives read at runtime.
            MediaQuery(
              data: mediaQuery.copyWith(disableAnimations: _reduceMotion),
              child: Column(
                // A ValueKey per state forces a fresh subtree, so one-shot
                // entrance animations replay when you switch states.
                key: ValueKey(_state),
                children: [
                  FixProviderCard(
                    state: _state,
                    name: 'Rahul Verma',
                    headline: 'Certified Plumber · FixNow Pro since 2020',
                    rating: 4.9,
                    reviewCount: 1284,
                    trustSignals: const [
                      FixTrustSignal(
                        label: 'ID verified',
                        icon: Icons.verified_user_rounded,
                      ),
                      FixTrustSignal(
                        label: 'Background checked',
                        icon: Icons.shield_rounded,
                      ),
                      FixTrustSignal(
                        label: 'On-time 98%',
                        icon: Icons.schedule_rounded,
                        tone: FixStatusTone.info,
                      ),
                    ],
                    stats: const [
                      FixProviderStat(value: 1284, label: 'Jobs done'),
                      FixProviderStat(
                        value: 6,
                        label: 'Experience',
                        suffix: ' yrs',
                      ),
                      FixProviderStat(
                        value: 41,
                        label: 'Repeat clients',
                        suffix: '%',
                      ),
                    ],
                    specialties: const [
                      'Leak repair',
                      'Tap & pipe fitting',
                      'Water heater',
                      'Drain cleaning',
                    ],
                    etaText: 'about 12 min',
                    distanceText: '1.2 km',
                    priceLabel: 'Visit & diagnosis',
                    priceAmount: 149,
                    priceNote: "Pay only after the job's done",
                    otp: '7362',
                    onCall: () => _toast('Calling Rahul…'),
                    onMessage: () => _toast('Opening chat…'),
                    onPrimaryAction: () => _toast(
                      _state == FixProviderCardState.arrived
                          ? 'Confirming start…'
                          : 'Opening live tracking…',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
