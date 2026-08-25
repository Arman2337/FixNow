import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:flutter/material.dart';

/// Availability state a [FixServiceCard] presents. The card is honest about
/// what the customer will actually get right now, so the same surface can say
/// "help is a few minutes away", "we're busy but you can still book", or
/// "we're closed — schedule ahead" without changing shape.
enum FixServiceCardState {
  /// Pros are free nearby — the reassuring default (green live strip).
  available,

  /// Demand is high: fewer pros, longer waits (gold "BUSY" live strip).
  inDemand,

  /// Outside working hours — no live pros; the customer books ahead (muted).
  afterHours,
}

/// FixNow's service-selection card — the tappable surface a customer uses to
/// choose what needs fixing. It is the search/browse sibling of
/// [FixProviderCard] and speaks the same cobalt & gold language.
///
/// Signature element: the **live availability strip** — a pulsing dot, a
/// plain-language "N pros available now" line, and a small stack of real
/// pro avatars — so the customer sees that help is genuinely standing by
/// before they commit.
///
/// It is presentational: pass data in and wire the callbacks; it holds no
/// business logic and fetches nothing. All motion (the tile's gold spark, the
/// live pulse, the avatar pop-in) is delegated to the shared `fix_motion`
/// primitives, so the card degrades to a calm, static presentation when
/// `MediaQuery.disableAnimations` is set.
class FixServiceCard extends StatelessWidget {
  const FixServiceCard({
    required this.name,
    this.state = FixServiceCardState.available,
    this.description,
    this.icon = Icons.build_rounded,
    this.rating,
    this.reviewCount,
    this.etaText,
    this.prosAvailable = 0,
    this.proInitials = const <String>['R', 'S', 'K'],
    this.opensAtText,
    this.priceFrom,
    this.priceCurrency = '₹',
    this.priceNote = 'visit & diagnosis',
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onTap,
    super.key,
  });

  /// Service name, e.g. "Plumbing".
  final String name;

  /// Availability state to present.
  final FixServiceCardState state;

  /// One-line supporting description, e.g. "Leaks, taps, fittings & drainage".
  final String? description;

  /// Glyph shown in the service tile.
  final IconData icon;

  /// Average rating out of 5. The rating chip is hidden when null.
  final double? rating;

  /// Number of ratings behind [rating]. Formatted compactly (e.g. 2300 → 2.3k).
  final int? reviewCount;

  /// Human ETA phrase, e.g. "~12 min". Shown as "… away" unless after hours.
  final String? etaText;

  /// How many pros are live nearby — drives the strip text and avatar stack.
  final int prosAvailable;

  /// Sample pro initials for the avatar stack (presentational; cycles if the
  /// count exceeds the list length).
  final List<String> proInitials;

  /// Opening time phrase for [FixServiceCardState.afterHours], e.g. "7:00 AM".
  final String? opensAtText;

  /// "From" price. The price line is hidden when null.
  final num? priceFrom;

  /// Currency symbol for [priceFrom].
  final String priceCurrency;

  /// Reassuring sub-line under the price.
  final String priceNote;

  /// Overrides the primary button label. Defaults per [state].
  final String? primaryActionLabel;

  /// Primary call-to-action (Book / Schedule). Disabled when null.
  final VoidCallback? onPrimaryAction;

  /// Whole-card tap — opens the service, distinct from the primary CTA.
  final VoidCallback? onTap;

  bool get _isAfterHours => state == FixServiceCardState.afterHours;

  String get _defaultActionLabel => switch (state) {
        FixServiceCardState.available => 'Book',
        FixServiceCardState.inDemand => 'Book anyway',
        FixServiceCardState.afterHours => 'Schedule',
      };

  @override
  Widget build(BuildContext context) {
    return FixCard(
      tone: FixCardTone.cream,
      onTap: onTap,
      semanticLabel: _semanticLabel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopRow(
            name: name,
            description: description,
            icon: icon,
            rating: rating,
            reviewCount: reviewCount,
            etaText: _isAfterHours ? null : etaText,
            muted: _isAfterHours,
          ),
          const SizedBox(height: AppSpacing.md),
          _LiveStrip(
            state: state,
            prosAvailable: prosAvailable,
            proInitials: proInitials,
            opensAtText: opensAtText,
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1, color: AppColors.borderDefault),
          const SizedBox(height: AppSpacing.md),
          _Foot(
            priceFrom: priceFrom,
            priceCurrency: priceCurrency,
            priceNote: priceNote,
            actionLabel: primaryActionLabel ?? _defaultActionLabel,
            actionIcon: _isAfterHours ? Icons.calendar_today_rounded : null,
            // "Book →": a forward arrow trails the booking CTAs; the
            // after-hours "Schedule" keeps its leading calendar glyph instead.
            actionTrailingIcon:
                _isAfterHours ? null : Icons.arrow_forward_rounded,
            actionVariant: _isAfterHours
                ? FixButtonVariant.secondary
                : FixButtonVariant.primary,
            onAction: onPrimaryAction,
          ),
        ],
      ),
    );
  }

  String _semanticLabel() {
    final buffer = StringBuffer(name);
    if (priceFrom != null) {
      buffer.write(', from $priceCurrency${_formatPrice(priceFrom!)}');
    }
    switch (state) {
      case FixServiceCardState.available:
        if (prosAvailable > 0) buffer.write(', $prosAvailable pros available now');
      case FixServiceCardState.inDemand:
        buffer.write(', in high demand');
        if (prosAvailable > 0) buffer.write(', $prosAvailable pros nearby');
      case FixServiceCardState.afterHours:
        if (opensAtText != null) buffer.write(', opens $opensAtText');
    }
    return buffer.toString();
  }
}

/// Icon tile + service identity (name, description, rating · ETA) + a chevron
/// affordance hinting the whole card is tappable.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.name,
    required this.description,
    required this.icon,
    required this.rating,
    required this.reviewCount,
    required this.etaText,
    required this.muted,
  });

  final String name;
  final String? description;
  final IconData icon;
  final double? rating;
  final int? reviewCount;
  final String? etaText;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ServiceTile(icon: icon, muted: muted),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 3),
                Text(
                  description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textOnSurfaceSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
              if (rating != null) ...[
                const SizedBox(height: 7),
                _MetaRow(
                  rating: rating!,
                  reviewCount: reviewCount,
                  etaText: etaText,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Nudge the chevron down so it sits at the tile's vertical centre.
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: _Chevron(),
        ),
      ],
    );
  }
}

/// The service glyph in a soft cobalt tile. In the available/in-demand states a
/// small gold spark pops in (via [FixScaleIn]); the after-hours tile is muted
/// and carries no spark.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.muted});

  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.borderDefault),
        gradient: muted
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cream, AppColors.primarySoft],
              ),
        color: muted ? AppColors.surfaceSecondary : null,
      ),
      child: Icon(
        icon,
        size: 27,
        color: muted ? AppColors.textOnSurfaceMuted : AppColors.primary,
      ),
    );

    if (muted) return tile;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: -2,
          right: -2,
          child: FixScaleIn(
            delay: const Duration(milliseconds: 400),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cream, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact "★ 4.9 (2.3k) · ⏱ ~12 min away" meta line. The ETA half is dropped
/// when [etaText] is null (e.g. after hours).
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.rating,
    required this.reviewCount,
    required this.etaText,
  });

  final double rating;
  final int? reviewCount;
  final String? etaText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 14, color: AppColors.rating),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: AppTypography.label.copyWith(
            color: AppColors.textOnSurface,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '(${_formatCompactCount(reviewCount!)})',
            style: AppTypography.caption.copyWith(
              color: AppColors.textOnSurfaceMuted,
              fontSize: 12.5,
            ),
          ),
        ],
        if (etaText != null) ...[
          const SizedBox(width: 7),
          _DotSeparator(),
          const SizedBox(width: 7),
          Icon(Icons.schedule_rounded, size: 13, color: AppColors.textOnSurfaceMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$etaText away',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textOnSurfaceSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A small 3×3 dot used to separate meta fragments.
class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: AppColors.borderStrong,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The round chevron affordance, hinting the whole card opens the service.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCream,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }
}

/// Signature element — the live availability strip. Colour, dot behaviour, and
/// copy shift per state: green + pulse + avatar stack when available, gold +
/// "BUSY" chip when in demand, muted + static dot after hours.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({
    required this.state,
    required this.prosAvailable,
    required this.proInitials,
    required this.opensAtText,
  });

  final FixServiceCardState state;
  final int prosAvailable;
  final List<String> proInitials;
  final String? opensAtText;

  @override
  Widget build(BuildContext context) {
    final (Color soft, Color border, Color dot) = switch (state) {
      FixServiceCardState.available => (
          AppColors.successSoft,
          AppColors.success.withValues(alpha: 0.20),
          AppColors.success,
        ),
      FixServiceCardState.inDemand => (
          AppColors.accentGoldSoft,
          AppColors.borderGold,
          AppColors.accentGold,
        ),
      FixServiceCardState.afterHours => (
          AppColors.surfaceCream,
          AppColors.borderDefault,
          AppColors.textOnSurfaceMuted,
        ),
    };

    final showStack =
        state != FixServiceCardState.afterHours && prosAvailable > 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _StripDot(
            color: dot,
            pulse: state != FixServiceCardState.afterHours,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _stripText()),
          if (showStack) ...[
            const SizedBox(width: AppSpacing.sm),
            _ProStack(
              count: prosAvailable,
              initials: proInitials,
              borderColor: soft,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stripText() {
    switch (state) {
      case FixServiceCardState.available:
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$prosAvailable pros',
                style: AppTypography.label.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              TextSpan(
                text: ' available now',
                style: AppTypography.label.copyWith(
                  color: AppColors.textOnSurfaceSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case FixServiceCardState.inDemand:
        return Row(
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$prosAvailable pros',
                      style: AppTypography.label.copyWith(
                        color: AppColors.onAccentGold,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    TextSpan(
                      text: ' nearby',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textOnSurfaceSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const _SurgeChip(),
          ],
        );
      case FixServiceCardState.afterHours:
        final opens = opensAtText == null ? '' : 'Opens $opensAtText · ';
        return Text(
          '${opens}book ahead',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(
            color: AppColors.textOnSurfaceSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        );
    }
  }
}

/// The live dot. Pulses gently (via [FixPulse]) unless [pulse] is false, in
/// which case it renders as a calm static dot (after-hours).
class _StripDot extends StatelessWidget {
  const _StripDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
    if (!pulse) return dot;
    return FixPulse(maxScale: 1.35, child: dot);
  }
}

/// The gold "BUSY" surge pill shown in the in-demand strip.
class _SurgeChip extends StatelessWidget {
  const _SurgeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentGoldHover,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'BUSY',
        style: AppTypography.caption.copyWith(
          color: AppColors.onAccentGold,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Overlapping stack of small pro avatars (real people ready now). Shows up to
/// three initials plus a "+N" bubble. Each avatar pops in on a short stagger
/// via [FixScaleIn], which idles under reduce-motion.
class _ProStack extends StatelessWidget {
  const _ProStack({
    required this.count,
    required this.initials,
    required this.borderColor,
  });

  final int count;
  final List<String> initials;
  final Color borderColor;

  static const double _size = 24;
  static const double _step = 16;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final shown = count < 3 ? count : 3;
    final hasMore = count > 3;
    final bubbles = shown + (hasMore ? 1 : 0);
    final width = _size + (bubbles - 1) * _step;

    final children = <Widget>[];
    for (var i = 0; i < shown; i++) {
      final label = initials.isEmpty ? '•' : initials[i % initials.length];
      children.add(
        Positioned(
          left: i * _step,
          child: FixScaleIn(
            from: 0.4,
            delay: Duration(milliseconds: 220 + i * 60),
            child: _ProAvatar(
              label: label,
              gradientIndex: i,
              borderColor: borderColor,
            ),
          ),
        ),
      );
    }
    if (hasMore) {
      children.add(
        Positioned(
          left: shown * _step,
          child: FixScaleIn(
            from: 0.4,
            delay: Duration(milliseconds: 220 + shown * 60),
            child: _MoreBubble(extra: count - 3, borderColor: borderColor),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

/// One circular gradient avatar with an initial, ringed in the strip colour so
/// overlapping avatars read as cleanly cut out.
class _ProAvatar extends StatelessWidget {
  const _ProAvatar({
    required this.label,
    required this.gradientIndex,
    required this.borderColor,
  });

  final String label;
  final int gradientIndex;
  final Color borderColor;

  static const List<List<Color>> _gradients = [
    [AppColors.primary, AppColors.primaryHover],
    [AppColors.primaryPressed, AppColors.primary],
    [AppColors.primaryHover, AppColors.primaryPressed],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradients[gradientIndex % _gradients.length],
        ),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
          height: 1.0,
        ),
      ),
    );
  }
}

/// The trailing "+N" bubble when more pros are available than shown.
class _MoreBubble extends StatelessWidget {
  const _MoreBubble({required this.extra, required this.borderColor});

  final int extra;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Text(
        '+$extra',
        style: AppTypography.caption.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          height: 1.0,
        ),
      ),
    );
  }
}

/// The price ("from ₹149" + note) beside the primary CTA.
class _Foot extends StatelessWidget {
  const _Foot({
    required this.priceFrom,
    required this.priceCurrency,
    required this.priceNote,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionTrailingIcon,
    required this.actionVariant,
    required this.onAction,
  });

  final num? priceFrom;
  final String priceCurrency;
  final String priceNote;
  final String actionLabel;
  final IconData? actionIcon;
  final IconData? actionTrailingIcon;
  final FixButtonVariant actionVariant;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (priceFrom != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'from',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textOnSurfaceMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$priceCurrency${_formatPrice(priceFrom!)}',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.textOnSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  priceNote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textOnSurfaceMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.md),
        FixButton(
          label: actionLabel,
          icon: actionIcon,
          trailingIcon: actionTrailingIcon,
          variant: actionVariant,
          onPressed: onAction,
          height: 46,
        ),
      ],
    );
  }
}

/// Formats a "from" price without a trailing ".0" for whole rupee amounts.
String _formatPrice(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Compacts a non-negative count: 980 → "980", 2300 → "2.3k", 3100 → "3.1k".
String _formatCompactCount(int value) {
  if (value < 1000) return value.toString();
  final thousands = value / 1000.0;
  final oneDp = thousands.toStringAsFixed(1);
  final trimmed = oneDp.endsWith('.0') ? oneDp.substring(0, oneDp.length - 2) : oneDp;
  return '${trimmed}k';
}
