import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:flutter/material.dart';

/// Lifecycle state a [FixProviderCard] presents. The same card carries a
/// customer from match through arrival, so trust builds in one familiar place.
enum FixProviderCardState {
  /// No professional matched yet — shows a shape-matched loading skeleton.
  finding,

  /// A professional accepted and is travelling to the customer.
  enRoute,

  /// The professional has reached the customer's location.
  arrived,
}

/// A single trust signal rendered as a pill (e.g. "ID verified"). Reuses
/// [FixStatusChip] so trust markers look identical everywhere they appear.
class FixTrustSignal {
  const FixTrustSignal({
    required this.label,
    this.icon = Icons.verified_user_rounded,
    this.tone = FixStatusTone.success,
  });

  final String label;
  final IconData icon;
  final FixStatusTone tone;
}

/// A single headline stat (e.g. 1284 "Jobs done"). The value rolls up with
/// [FixCountUp] unless the platform requests reduced motion.
class FixProviderStat {
  const FixProviderStat({
    required this.value,
    required this.label,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
  });

  final num value;
  final String label;
  final String prefix;
  final String suffix;
  final int fractionDigits;
}

/// FixNow's provider trust card — the "who's coming to help" surface intended
/// for reuse across search results and the live booking screen (see
/// `DESIGN.md` §34, §39: "Reuse `FixProviderCard`").
///
/// It is presentational: pass data in and wire the action callbacks; it holds
/// no business logic and fetches nothing. Motion (the verified-badge pop, the
/// live pulse, stat count-ups, and the loading shimmer) is delegated to the
/// shared `fix_motion` primitives, so the card degrades to a calm, static
/// presentation when `MediaQuery.disableAnimations` is set.
///
/// Start-code note: in the [FixProviderCardState.arrived] state the card shows
/// the customer's service start code inline (pass [otp]) so the whole arrival —
/// identity, live status, and the code to begin work — lives on one surface.
class FixProviderCard extends StatelessWidget {
  const FixProviderCard({
    this.state = FixProviderCardState.enRoute,
    this.name,
    this.headline,
    this.isVerified = true,
    this.rating,
    this.reviewCount,
    this.trustSignals = const <FixTrustSignal>[],
    this.stats = const <FixProviderStat>[],
    this.specialties = const <String>[],
    this.etaText,
    this.distanceText,
    this.priceLabel,
    this.priceAmount,
    this.priceNote,
    this.priceCurrency = '₹',
    this.otp,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onCall,
    this.onMessage,
    super.key,
  });

  /// Lifecycle state to present.
  final FixProviderCardState state;

  /// Provider display name, e.g. "Rahul Verma".
  final String? name;

  /// Supporting identity line, e.g. "Certified Plumber · FixNow Pro since 2020".
  final String? headline;

  /// Whether to show the verified badge on the avatar.
  final bool isVerified;

  /// Average rating out of 5. Hidden when null.
  final double? rating;

  /// Number of ratings behind [rating].
  final int? reviewCount;

  /// Trust markers rendered as pills. Empty hides the row.
  final List<FixTrustSignal> trustSignals;

  /// Headline stats rendered as count-up tiles. Empty hides the row.
  final List<FixProviderStat> stats;

  /// Specialty tags. Empty hides the section.
  final List<String> specialties;

  /// Human ETA phrase for the en-route state, e.g. "about 12 min".
  final String? etaText;

  /// Human distance phrase, e.g. "1.2 km". Shown as a pill while en route.
  final String? distanceText;

  /// Price line label. Defaults to "Visit & diagnosis" when an amount is set.
  final String? priceLabel;

  /// Price amount. The price line is hidden when null.
  final num? priceAmount;

  /// Reassuring sub-line under the price, e.g. "Pay only after the job's done".
  final String? priceNote;

  /// Currency symbol for the price amount.
  final String priceCurrency;

  /// Service start code. When set and [state] is
  /// [FixProviderCardState.arrived], the code is shown inline on the card.
  final String? otp;

  /// Overrides the primary button label. Defaults per [state].
  final String? primaryActionLabel;

  /// Primary call-to-action. Hidden when null.
  final VoidCallback? onPrimaryAction;

  /// Voice-call action. Hidden when null.
  final VoidCallback? onCall;

  /// In-app message action. Hidden when null.
  final VoidCallback? onMessage;

  String get _firstName {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'Your pro';
    return trimmed.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    if (state == FixProviderCardState.finding) {
      return const FixCard(
        semanticLabel: 'Finding a verified professional',
        child: _FindingContent(),
      );
    }

    final showActions =
        onPrimaryAction != null || onCall != null || onMessage != null;
    final showLive = state == FixProviderCardState.arrived || etaText != null;

    return FixCard(
      semanticLabel: 'Assigned professional',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Identity(
            name: name ?? 'Your pro',
            headline: headline,
            isVerified: isVerified,
            rating: rating,
            reviewCount: reviewCount,
          ),
          if (showLive) ...[
            const SizedBox(height: AppSpacing.lg),
            _LiveStrip(
              state: state,
              firstName: _firstName,
              etaText: etaText,
              distanceText: distanceText,
            ),
          ],
          if (trustSignals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final signal in trustSignals)
                  FixStatusChip(
                    label: signal.label,
                    icon: signal.icon,
                    tone: signal.tone,
                  ),
              ],
            ),
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _StatsRow(stats: stats),
          ],
          if (state == FixProviderCardState.arrived &&
              otp != null &&
              otp!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _StartCode(code: otp!),
          ],
          if (specialties.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Specialties(specialties: specialties),
          ],
          if (priceAmount != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _PriceRow(
              label: priceLabel ?? 'Visit & diagnosis',
              amount: priceAmount!,
              note: priceNote,
              currency: priceCurrency,
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: AppSpacing.lg),
            _Actions(
              primaryLabel: primaryActionLabel ??
                  (state == FixProviderCardState.arrived
                      ? 'Confirm start'
                      : 'Track live'),
              primaryIcon: state == FixProviderCardState.arrived
                  ? Icons.check_circle_outline_rounded
                  : Icons.my_location_rounded,
              onPrimary: onPrimaryAction,
              onCall: onCall,
              onMessage: onMessage,
            ),
          ],
        ],
      ),
    );
  }
}

/// Avatar + name + trade + rating. The verified badge on the gradient avatar
/// pops in via [FixScaleIn], making identity the card's signature moment.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.headline,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
  });

  final String name;
  final String? headline;
  final bool isVerified;
  final double? rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GradientAvatar(name: name, isVerified: isVerified),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textOnSurface,
                ),
              ),
              if (headline != null) ...[
                const SizedBox(height: 2),
                Text(
                  headline!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textOnSurfaceSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
              if (rating != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _StarRating(rating: rating!, reviewCount: reviewCount),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A rounded-square gradient identity tile showing the provider's initials with
/// a verified badge that pops in via [FixScaleIn] — the card's signature
/// moment. Degrades to a static tile (badge already shown) under reduce-motion.
class _GradientAvatar extends StatelessWidget {
  const _GradientAvatar({required this.name, required this.isVerified});

  final String name;
  final bool isVerified;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final first = parts.first;
      return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryHover,
                AppColors.primaryPressed,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            _initials,
            style: AppTypography.heading3.copyWith(
              color: AppColors.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1.0,
            ),
          ),
        ),
        if (isVerified)
          Positioned(
            right: -3,
            bottom: -3,
            child: FixScaleIn(
              delay: const Duration(milliseconds: 280),
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfacePrimary, width: 3),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.onPrimary,
                  size: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Five stars that pop in with a stagger (via [FixScaleIn]) followed by the
/// numeric rating and review count. Stars fill to the rounded rating.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, this.reviewCount});

  final double rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          FixScaleIn(
            from: 0.4,
            delay: Duration(milliseconds: 300 + i * 70),
            child: Icon(
              i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i < filled ? AppColors.rating : AppColors.borderStrong,
              size: 15,
            ),
          ),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: AppTypography.label.copyWith(
            color: AppColors.textOnSurface,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '· ${_formatCount(reviewCount!)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textOnSurfaceMuted,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Groups a non-negative integer with thousands separators, e.g. 1284 → 1,284.
String _formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

/// Inline service start code for the arrived state: a short caption above a row
/// of digit boxes that pop in one after another (via [FixScaleIn]). Wrapped in
/// a [FittedBox] so longer codes never overflow on a narrow screen.
class _StartCode extends StatelessWidget {
  const _StartCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final digits = code.split('');
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Text(
            'Your start code — share it only after they arrive',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textOnSurfaceSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < digits.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  FixScaleIn(
                    from: 0.5,
                    delay: Duration(milliseconds: 60 + i * 70),
                    child: _DigitBox(digit: digits[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single gold-bordered start-code digit box, matching FixOtpDisplay's box
/// language (44×52, gold border, display digit) for a consistent code surface.
class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.digit});

  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.borderGold, width: 1.5),
      ),
      child: Text(
        digit,
        style: AppTypography.heading3.copyWith(
          color: AppColors.textOnSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Live status band: a pulsing dot plus a plain-language ETA/arrival line. Blue
/// while travelling, green on arrival, with a distance pill while en route.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({
    required this.state,
    required this.firstName,
    required this.etaText,
    required this.distanceText,
  });

  final FixProviderCardState state;
  final String firstName;
  final String? etaText;
  final String? distanceText;

  @override
  Widget build(BuildContext context) {
    final arrived = state == FixProviderCardState.arrived;
    final accent = arrived ? AppColors.success : AppColors.primary;
    final soft = arrived ? AppColors.successSoft : AppColors.primarySoft;

    final title = arrived ? '$firstName has arrived' : 'Arriving in ';
    final meta = arrived
        ? 'Share your start code to begin the work'
        : 'Heading to your location now';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _PulseDot(color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (arrived || etaText == null)
                  Text(
                    title,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textOnSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  )
                else
                  Text.rich(
                    TextSpan(
                      text: title,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textOnSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      children: [
                        TextSpan(
                          text: etaText,
                          style: TextStyle(color: accent),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 1),
                Text(
                  meta,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textOnSurfaceSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!arrived && distanceText != null) ...[
            const SizedBox(width: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  distanceText!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A live indicator dot with a soft glow that gently pulses via [FixPulse].
class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return FixPulse(
      maxScale: 1.35,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Equal-width tiles of headline stats.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<FixProviderStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _StatTile(stat: stats[i])),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final FixProviderStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FixCountUp(
            value: stat.value,
            prefix: stat.prefix,
            suffix: stat.suffix,
            fractionDigits: stat.fractionDigits,
            style: AppTypography.heading3.copyWith(
              color: AppColors.textOnSurface,
              fontSize: 19,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stat.label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textOnSurfaceMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled row of specialty tags.
class _Specialties extends StatelessWidget {
  const _Specialties({required this.specialties});

  final List<String> specialties;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SPECIALISES IN',
          style: AppTypography.caption.copyWith(
            color: AppColors.textOnSurfaceMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final specialty in specialties)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: AppColors.borderDefault),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    specialty,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textOnSurface,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Upfront, reassuring price line in the gold accent surface.
class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    required this.note,
    required this.currency,
  });

  final String label;
  final num amount;
  final String? note;
  final String currency;

  String get _amountText {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentGoldSoft,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.onAccentGold,
                    fontSize: 13,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onAccentGold.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$currency$_amountText',
            style: AppTypography.heading3.copyWith(
              color: AppColors.onAccentGold,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact call/message affordances beside one strong primary CTA
/// (`DESIGN.md` §39: "Present one strong primary CTA").
class _Actions extends StatelessWidget {
  const _Actions({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onCall,
    required this.onMessage,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onCall != null) ...[
          _IconAction(
            icon: Icons.call_rounded,
            label: 'Call',
            onTap: onCall!,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (onMessage != null) ...[
          _IconAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Message',
            onTap: onMessage!,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (onPrimary != null)
          Expanded(
            child: FixButton(
              label: primaryLabel,
              icon: primaryIcon,
              onPressed: onPrimary,
              expand: true,
              height: 50,
            ),
          ),
      ],
    );
  }
}

/// A square icon button matching the secondary button language, with a
/// press-in scale from [FixPressable].
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FixPressable(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            side: const BorderSide(color: AppColors.borderStrong),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: SizedBox(
              width: 52,
              height: 50,
              child: Center(
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shape-matched loading skeleton for [FixProviderCardState.finding]
/// (`DESIGN.md` §39: "Show a shape-matched skeleton while loading").
class _FindingContent extends StatelessWidget {
  const _FindingContent();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: FixShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _bar(60, 60, radius: AppRadius.large),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(150, 16),
                          const SizedBox(height: AppSpacing.sm),
                          _bar(100, 12),
                          const SizedBox(height: AppSpacing.sm),
                          _bar(80, 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _bar(double.infinity, 44, radius: AppRadius.medium),
                const SizedBox(height: AppSpacing.md),
                _bar(double.infinity, 64, radius: AppRadius.medium),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              // Under reduce-motion the shimmer idles, so the spinner would be
              // the only thing still moving — swap it for a static glyph to keep
              // the finding state fully calm and internally consistent.
              child: reduceMotion
                  ? const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppColors.primary,
                    )
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Matching you with a verified pro nearby…',
                style: AppTypography.body.copyWith(
                  color: AppColors.textOnSurfaceSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _bar(double width, double height, {double radius = AppRadius.small}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
