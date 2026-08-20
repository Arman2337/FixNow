import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';

/// Available Providers comparison sheet
class AvailableProvidersSheet extends StatelessWidget {
  const AvailableProvidersSheet({
    required this.serviceName,
    required this.onProviderSelected,
    super.key,
  });

  final String serviceName;
  final ValueChanged<String> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.sheetBorder,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Professionals',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const FixStatusChip(
                  label: 'Nearby',
                  icon: Icons.location_searching_rounded,
                  tone: FixStatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Verified technicians ready for $serviceName',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildProviderCard(
              context,
              name: 'Amit Sharma',
              rating: 4.8,
              reviews: 126,
              jobs: '450+ jobs',
              experience: '15+ yrs exp',
              distance: '2.1 km away',
              eta: 'ETA 12 min',
              price: '₹300 est.',
              isEmergencyReady: true,
            ),
            const SizedBox(height: AppSpacing.md),

            _buildProviderCard(
              context,
              name: 'Rajesh Patel',
              rating: 4.9,
              reviews: 89,
              jobs: '320+ jobs',
              experience: '8+ yrs exp',
              distance: '3.4 km away',
              eta: 'ETA 18 min',
              price: '₹350 est.',
              isEmergencyReady: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context, {
    required String name,
    required double rating,
    required int reviews,
    required String jobs,
    required String experience,
    required String distance,
    required String eta,
    required String price,
    required bool isEmergencyReady,
  }) {
    return FixCard(
      tone: FixCardTone.standard,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FixAvatar(name: name, size: 48, isVerified: true),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textOnLightPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const FixVerificationBadge(compact: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        FixRating(rating: rating, reviewCount: reviews),
                        const SizedBox(width: 8),
                        Text(
                          '• $experience',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _metricChip(Icons.work_history_outlined, jobs),
              _metricChip(Icons.navigation_outlined, distance),
              _metricChip(Icons.schedule_outlined, eta, color: AppColors.primary),
              if (isEmergencyReady)
                _metricChip(Icons.bolt_rounded, 'Emergency Ready', color: AppColors.accentGold),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.borderDefault, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size(100, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                ),
                onPressed: () => onProviderSelected(name),
                child: const Text(
                  'Select Pro',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(IconData icon, String text, {Color? color}) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: effectiveColor, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Booking Confirmed Celebration Dialog
class BookingConfirmedDialog extends StatelessWidget {
  const BookingConfirmedDialog({
    required this.bookingId,
    required this.serviceName,
    required this.onTrackBooking,
    this.providerName = 'Amit Sharma',
    this.estimatedArrival = '12 minutes',
    super.key,
  });

  final String bookingId;
  final String serviceName;
  final String providerName;
  final String estimatedArrival;
  final VoidCallback onTrackBooking;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Booking Confirmed!',
              style: AppTypography.heading2.copyWith(color: AppColors.cream),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'We have assigned a top-rated verified professional for your $serviceName.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            FixCard(
              tone: FixCardTone.standard,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Booking ID', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text(bookingId.substring(0, bookingId.length > 8 ? 8 : bookingId.length),
                          style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Professional', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text(providerName, style: const TextStyle(color: AppColors.textOnLightPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ETA', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text('About $estimatedArrival', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FixPrimaryButton(
              label: 'Track Booking',
              icon: Icons.navigation_rounded,
              onPressed: onTrackBooking,
            ),
          ],
        ),
      ),
    );
  }
}

/// Service Completed & 30-Day Warranty Dialog
class JobCompletedDialog extends StatelessWidget {
  const JobCompletedDialog({
    required this.onReviewAndPay,
    this.technicianName = 'Amit Sharma',
    this.duration = '45 min',
    this.completedTime = '03:05 PM',
    super.key,
  });

  final String technicianName;
  final String duration;
  final String completedTime;
  final VoidCallback onReviewAndPay;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.task_alt_rounded, color: AppColors.primary, size: 32),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Service Completed!',
              style: AppTypography.heading2.copyWith(color: AppColors.cream),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Great! Your home service is completed to the highest standard.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            FixCard(
              tone: FixCardTone.standard,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _summaryRow('Technician', technicianName),
                  _summaryRow('Service Duration', duration),
                  _summaryRow('Completed At', completedTime),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentGoldSoft,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderGold),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: AppColors.accentGold, size: 22),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FixNow Service Protection',
                          style: TextStyle(
                            color: AppColors.accentGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '30-day warranty on all eligible repair work.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            FixPrimaryButton(
              label: 'Review & Pay',
              icon: Icons.payments_outlined,
              onPressed: onReviewAndPay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(value, style: const TextStyle(color: AppColors.textOnLightPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

/// 5-Star Review & Rating Dialog
class ReviewRatingDialog extends StatefulWidget {
  const ReviewRatingDialog({
    required this.providerName,
    required this.onSubmit,
    super.key,
  });

  final String providerName;
  final ValueChanged<int> onSubmit;

  @override
  State<ReviewRatingDialog> createState() => _ReviewRatingDialogState();
}

class _ReviewRatingDialogState extends State<ReviewRatingDialog> {
  int _rating = 5;
  final _comment = TextEditingController();
  final _selectedTags = <String>{'On Time', 'Professional'};

  static const _quickTags = [
    'On Time',
    'Professional',
    'Quick Service',
    'Fair Pricing',
    'Clean Work',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rate your service',
              style: AppTypography.heading3.copyWith(color: AppColors.cream),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'How was your experience with ${widget.providerName}?',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++) ...[
                  IconButton(
                    iconSize: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.rating,
                    ),
                    onPressed: () => setState(() => _rating = i),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final tag in _quickTags) ...[
                  FilterChip(
                    label: Text(tag),
                    selected: _selectedTags.contains(tag),
                    selectedColor: AppColors.primarySoft,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedTags.contains(tag) ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            TextField(
              controller: _comment,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textOnLightPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Add an optional note about the repair quality...',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            FixPrimaryButton(
              label: 'Submit Review',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSubmit(_rating);
              },
            ),
          ],
        ),
      ),
    );
  }
}
