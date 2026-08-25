import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_service_card.dart';
import 'package:flutter/material.dart';

/// A standalone preview of [FixServiceCard] across its three availability
/// states, with a reduce-motion toggle. This is a design-system harness, not a
/// product screen: it is not wired into navigation. Push to it from anywhere to
/// review the card on a real device, e.g.
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute<void>(builder: (_) => const FixServiceCardGallery()),
/// );
/// ```
class FixServiceCardGallery extends StatefulWidget {
  const FixServiceCardGallery({super.key});

  @override
  State<FixServiceCardGallery> createState() => _FixServiceCardGalleryState();
}

class _FixServiceCardGalleryState extends State<FixServiceCardGallery> {
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
        title: const Text('FixServiceCard'),
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: MediaQuery(
          // Overriding disableAnimations lets the toggle exercise the exact
          // reduce-motion path the fix_motion primitives read at runtime.
          data: mediaQuery.copyWith(disableAnimations: _reduceMotion),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
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
              const SizedBox(height: AppSpacing.sm),
              // A ValueKey tied to the toggle forces a fresh subtree, so the
              // one-shot entrance animations replay when it changes.
              Column(
                key: ValueKey(_reduceMotion),
                children: [
                  _Label('Available'),
                  FixServiceCard(
                    name: 'Plumbing',
                    description: 'Leaks, taps, fittings & drainage',
                    icon: Icons.plumbing_rounded,
                    rating: 4.9,
                    reviewCount: 2300,
                    etaText: '~12 min',
                    prosAvailable: 12,
                    priceFrom: 149,
                    onPrimaryAction: () => _toast('Booking Plumbing…'),
                    onTap: () => _toast('Opening Plumbing'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Label('In demand (surge)'),
                  FixServiceCard(
                    name: 'AC Service & Repair',
                    description: 'Gas refill, servicing, install',
                    icon: Icons.ac_unit_rounded,
                    state: FixServiceCardState.inDemand,
                    rating: 4.9,
                    reviewCount: 980,
                    etaText: '~30 min',
                    prosAvailable: 3,
                    priceFrom: 299,
                    onPrimaryAction: () => _toast('Booking AC Service…'),
                    onTap: () => _toast('Opening AC Service'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Label('After hours'),
                  FixServiceCard(
                    name: 'Deep Cleaning',
                    description: 'Kitchen, bathroom & full home',
                    icon: Icons.cleaning_services_rounded,
                    state: FixServiceCardState.afterHours,
                    rating: 4.7,
                    reviewCount: 3100,
                    opensAtText: '7:00 AM',
                    priceFrom: 499,
                    onPrimaryAction: () => _toast('Scheduling Deep Cleaning…'),
                    onTap: () => _toast('Opening Deep Cleaning'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small section label above each preview card.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          fontSize: 11,
        ),
      ),
    );
  }
}
