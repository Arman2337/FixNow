import 'package:fixnow_mobile/design_system/signature_motion.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';

/// Standard FixNow Form Input Field
class FixTextField extends StatelessWidget {
  const FixTextField({
    required this.label,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textOnSurfaceSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(color: AppColors.textOnSurface, fontSize: 15),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfacePrimary,
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputBorder,
              borderSide: const BorderSide(color: AppColors.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputBorder,
              borderSide: const BorderSide(color: AppColors.borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputBorder,
              borderSide: const BorderSide(color: AppColors.focus, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Search Input Bar
class FixSearchField extends StatelessWidget {
  const FixSearchField({
    this.controller,
    this.hintText = 'Search services, problems, or tools...',
    this.onChanged,
    this.onSubmitted,
    this.onMicPressed,
    super.key,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onMicPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.borderDefault),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                color: AppColors.textOnSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          if (onMicPressed != null) ...[
            IconButton(
              icon: const Icon(
                Icons.mic_rounded,
                color: AppColors.accentGold,
                size: 20,
              ),
              onPressed: onMicPressed,
              splashRadius: 20,
            ),
          ],
        ],
      ),
    );
  }
}

/// Section Header with optional action link
class FixSectionHeader extends StatelessWidget {
  const FixSectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.useSerif = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool useSerif;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: useSerif
                    ? FixNowTypography.heading3.copyWith(
                        color: AppColors.textPrimary,
                      )
                    : const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              GestureDetector(
                onTap: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// User/Provider Avatar with verified badge indicator
class FixAvatar extends StatelessWidget {
  const FixAvatar({
    this.name,
    this.imageUrl,
    this.size = 48.0,
    this.isVerified = false,
    this.badgeSize = 14.0,
    super.key,
  });

  final String? name;
  final String? imageUrl;
  final double size;
  final bool isVerified;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    final initials = (name != null && name!.trim().isNotEmpty)
        ? name!
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'FX';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceSecondary,
            border: Border.all(color: AppColors.borderStrong, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.4,
            ),
          ),
        ),
        if (isVerified)
          Positioned(
            right: -2,
            bottom: -2,
            child: FixScaleIn(
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: AppColors.verified,
                  size: badgeSize,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Star Rating Component with Review Count
class FixRating extends StatelessWidget {
  const FixRating({
    required this.rating,
    this.reviewCount,
    this.starSize = 14.0,
    this.fontSize = 13.0,
    super.key,
  });

  final double rating;
  final int? reviewCount;
  final double starSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.star_rounded, color: AppColors.rating, size: starSize),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: AppColors.textOnLightPrimary,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 3),
          Text(
            '($reviewCount)',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: fontSize * 0.9,
            ),
          ),
        ],
      ],
    );
  }
}

/// 24/7 Emergency Service Banner
class FixEmergencyBanner extends StatelessWidget {
  const FixEmergencyBanner({
    required this.onCallNow,
    this.title = 'Emergency Help',
    this.subtitle = 'Immediate assistance available 24/7.',
    super.key,
  });

  final VoidCallback onCallNow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.onError.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.crisis_alert_rounded,
                      color: AppColors.onError,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Emergency Home Hazards?' : title,
                        style: FixNowTypography.title.copyWith(
                          color: AppColors.onError,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Priority SOS Field Unit Ready',
                        style: FixNowTypography.labelSmall.copyWith(
                          color: AppColors.onError.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.onError,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '15-min ETA',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle.isEmpty
                ? 'Direct dispatch for gas leaks, pipe bursts & sparking panels. Immediate priority routing.'
                : subtitle,
            style: FixNowTypography.bodySmall.copyWith(
              color: AppColors.onError.withValues(alpha: 0.95),
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.security_rounded, color: AppColors.onError.withValues(alpha: 0.9), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Zero surge dispatch fee',
                    style: FixNowTypography.labelSmall.copyWith(
                      color: AppColors.onError.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLowest,
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onCallNow,
                icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                label: const Text(
                  'Call SOS Dispatch',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ask FixNow AI Problem Bar (Stitch FixAI Diagnostic BETA banner)
class FixAiPromptCard extends StatelessWidget {
  const FixAiPromptCard({
    required this.onScan,
    required this.onSpeak,
    super.key,
  });

  final VoidCallback onScan;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'FixAI Diagnostic',
                              style: FixNowTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'BETA',
                              style: FixNowTypography.labelSmall.copyWith(
                                color: AppColors.onPrimaryFixed,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unsure what is broken?',
                        style: FixNowTypography.title.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Take a quick photo or describe the sound to auto-classify failure & estimate repairs instantly.',
                        style: FixNowTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onScan,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.document_scanner_rounded, size: 18),
                    label: const Text('Scan with FixAI', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSpeak,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.borderDefault),
                      ),
                    ),
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Speak', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }
}


/// 7-Stage Service Lifecycle Timeline
class FixTimeline extends StatelessWidget {
  const FixTimeline({required this.currentStatus, super.key});

  final String currentStatus;

  static const _stages = [
    ('REQUESTED', 'Requested', 'Matching eligible pros'),
    ('ASSIGNED', 'Accepted', 'Pro confirmed booking'),
    ('EN_ROUTE', 'On the Way', 'Pro is traveling to you'),
    ('ARRIVED', 'Arrived', 'Pro has reached location'),
    ('OTP_VERIFIED', 'OTP Verified', 'Safety verification passed'),
    ('IN_PROGRESS', 'Work Started', 'Repair in progress'),
    ('COMPLETED', 'Completed', 'Job finished & verified'),
  ];

  int get _currentIndex {
    return switch (currentStatus.toUpperCase()) {
      'REQUESTED' => 0,
      'ASSIGNED' || 'ACCEPTED' => 1,
      'EN_ROUTE' => 2,
      'ARRIVED' => 3,
      'OTP_VERIFIED' => 4,
      'IN_PROGRESS' => 5,
      'COMPLETED' => 6,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _currentIndex;

    return Column(
      children: [
        for (var i = 0; i < _stages.length; i++) ...[
          _TimelineStep(
            title: _stages[i].$2,
            subtitle: _stages[i].$3,
            isCompleted: i < activeIndex,
            isCurrent: i == activeIndex,
            isLast: i == _stages.length - 1,
          ),
        ],
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = isCompleted
        ? AppColors.primary
        : (isCurrent ? AppColors.accentGold : AppColors.surfaceSecondary);
    final dotBorder = isCompleted
        ? AppColors.primary
        : (isCurrent ? AppColors.accentGold : AppColors.borderDefault);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                _TimelineDot(
                  color: dotColor,
                  borderColor: dotBorder,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                ),
                if (!isLast)
                  Expanded(
                    child: AnimatedContainer(
                      duration: AppMotion.emphasis,
                      curve: AppMotion.standardCurve,
                      width: 2,
                      color: isCompleted
                          ? AppColors.primary
                          : AppColors.borderDefault,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.emphasis,
                    curve: AppMotion.standardCurve,
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.accentGold
                          : (isCompleted
                                ? AppColors.textPrimary
                                : AppColors.textMuted),
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
                    child: Text(title),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Timeline node: an animated dot that recolours as a step progresses. The
/// current step gets a gentle pulse; a completed step pops its check in.
class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.color,
    required this.borderColor,
    required this.isCompleted,
    required this.isCurrent,
  });

  final Color color;
  final Color borderColor;
  final bool isCompleted;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: AppMotion.emphasis,
      curve: AppMotion.standardCurve,
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: isCompleted
          ? const FixScaleIn(
              from: 0.2,
              child: Icon(Icons.check, size: 10, color: AppColors.onPrimary),
            )
          : null,
    );
    return isCurrent ? FixPulse(maxScale: 1.25, child: dot) : dot;
  }
}

/// Live OTP Security Shield Display Box for Service Start
class FixOtpDisplay extends StatelessWidget {
  const FixOtpDisplay({this.otp = '7362', super.key});

  final String otp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.accentGold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SERVICE START CODE',
                style: FixNowTypography.caption.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FlipOtpDigits(otp: otp),
          const SizedBox(height: AppSpacing.md),
          // Branded Security Shield Anti-Fraud Container
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.backgroundPrimary,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.lock_person_rounded,
                    color: AppColors.accentGold,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FixNow Anti-Fraud Protection',
                        style: FixNowTypography.caption.copyWith(
                          color: AppColors.cream,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Do NOT share this code over phone, SMS, or chat. Share ONLY in person when the technician is physically at your doorstep.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Transparent Invoice Breakdown Card
class FixInvoiceCard extends StatelessWidget {
  const FixInvoiceCard({
    required this.serviceFee,
    this.partsFee = 0,
    this.platformFee = 49,
    this.tax = 35,
    this.discount = 0,
    this.isEstimated = true,
    super.key,
  });

  final int serviceFee;
  final int partsFee;
  final int platformFee;
  final int tax;
  final int discount;
  final bool isEstimated;

  int get total => (serviceFee + partsFee + platformFee + tax) - discount;

  @override
  Widget build(BuildContext context) {
    return FixCard(
      tone: FixCardTone.elevated,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Breakdown',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (isEstimated)
                const FixStatusChip(
                  label: 'Estimated',
                  icon: Icons.info_outline_rounded,
                  tone: FixStatusTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InvoiceRow(label: 'Service Visit & Labor', amount: '₹$serviceFee'),
          if (partsFee > 0)
            _InvoiceRow(label: 'Parts & Materials', amount: '₹$partsFee'),
          _InvoiceRow(label: 'Platform Fee', amount: '₹$platformFee'),
          _InvoiceRow(label: 'Taxes (GST)', amount: '₹$tax'),
          if (discount > 0)
            _InvoiceRow(
              label: 'Discount',
              amount: '-₹$discount',
              color: AppColors.success,
            ),
          const Divider(color: AppColors.borderDefault, height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Payable',
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              FixCountUp(
                value: total,
                prefix: '₹',
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Pay only after confirming job completion.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.label, required this.amount, this.color});

  final String label;
  final String amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
