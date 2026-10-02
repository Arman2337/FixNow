import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:flutter/material.dart';

class FixEmptyState extends StatelessWidget {
  const FixEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => FixFadeSlideIn(
    offsetY: 0.10,
    child: _FixStateView(
      icon: icon,
      iconColor: AppColors.primary,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

class FixErrorState extends StatelessWidget {
  const FixErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _FixStateView(
    icon: Icons.error_outline_rounded,
    iconColor: AppColors.danger,
    title: title,
    message: message,
    actionLabel: retryLabel,
    onAction: onRetry,
  );
}

class FixOfflineBanner extends StatelessWidget {
  const FixOfflineBanner({
    this.message = 'You are offline. Some information may be out of date.',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.warningSoft,
          border: Border(bottom: BorderSide(color: AppColors.warning)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
}

/// PERF-005. Says the screen may be showing an old state, and offers a retry.
///
/// Separate from [FixOfflineBanner] rather than a parameter of it, because the
/// two mean different things and the app is in only one of them at a time. The
/// offline banner tells the user their device has no network, which they can act
/// on by walking out of a lift. This one says the *server* stopped updating us,
/// which happens on a perfectly good connection - most often because the app was
/// suspended and the socket was terminated while it slept. Telling someone they
/// are offline when their signal is full bars is the kind of small lie that makes
/// people turn off the one indicator they needed.
class FixStaleDataBanner extends StatelessWidget {
  const FixStaleDataBanner({
    this.message =
        'Live updates paused. This may not be the latest - pull to refresh.',
    this.onRetry,
    this.retryLabel = 'Reconnect',
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.warningSoft,
          border: Border(bottom: BorderSide(color: AppColors.warning)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sync_problem_rounded,
              color: AppColors.warning,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textOnSurface,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    ),
  );
}

class FixSkeleton extends StatelessWidget {
  const FixSkeleton({
    required this.height,
    this.width,
    this.radius,
    this.semanticsLabel,
    super.key,
  });

  final double height;
  final double? width;
  final BorderRadius? radius;

  /// MOB-005. Announced, unlike the boxes in the composed skeletons below.
  ///
  /// A bare placeholder is decoration and correctly hidden from a screen reader.
  /// A page-sized one is not: it is the whole content, so without a label the
  /// first thing a screen-reader user meets on a loading page is an empty
  /// document, and "Loading" is the only thing worth saying.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: radius ?? BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.borderDefault),
      ),
    );
    if (semanticsLabel == null) {
      return ExcludeSemantics(child: FixShimmer(child: box));
    }
    return Semantics(
      liveRegion: true,
      label: semanticsLabel,
      child: ExcludeSemantics(child: FixShimmer(child: box)),
    );
  }
}

/// MOB-005. Composed skeletons for the shapes that actually appear while content
/// loads.
///
/// [FixSkeleton] on its own is a grey box, and a page of grey boxes tells the
/// user nothing about what is arriving - or that the layout they are about to see
/// will not jump. These are shaped like the content they stand in for, which is
/// the actual reason to prefer a skeleton to a spinner: the page reserves the
/// right space up front.
///
/// Everything here is a pure composition of [FixSkeleton], so a screen can still
/// hand-roll a shape these do not cover without leaving the design system.
class FixSkeletonLines extends StatelessWidget {
  const FixSkeletonLines({
    this.count = 3,
    this.lineHeight = 12,
    this.spacing = 8,
    this.lastLineFraction = 0.6,
    this.semanticsLabel,
    super.key,
  });

  final int count;
  final double lineHeight;
  final double spacing;

  /// The last line is short, because a paragraph of equal-length bars reads as a
  /// table and a table is not what is loading.
  final double lastLineFraction;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < count; index += 1)
          Padding(
            padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : spacing),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: index == count - 1 ? lastLineFraction : 1,
              child: FixSkeleton(
                height: lineHeight,
                radius: BorderRadius.circular(lineHeight / 2),
              ),
            ),
          ),
      ],
    ),
  );
}

/// A circle plus two lines: the shape of a person in a list.
class FixSkeletonIdentity extends StatelessWidget {
  const FixSkeletonIdentity({
    this.avatarSize = 40,
    this.lineHeight = 12,
    this.semanticsLabel,
    super.key,
  });

  final double avatarSize;
  final double lineHeight;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Not const: the radius is derived from avatarSize, so this cannot be a
        // compile-time constant.
        FixSkeleton(
          height: avatarSize,
          width: avatarSize,
          radius: BorderRadius.circular(avatarSize / 2),
        ),
        const SizedBox(width: AppSpacing.md),
        // Not const either: lineHeight is a field.
        Expanded(child: FixSkeletonLines(count: 2, lineHeight: lineHeight)),
      ],
    ),
  );
}

/// A bordered card with an identity row and a couple of lines under it.
class FixSkeletonCard extends StatelessWidget {
  const FixSkeletonCard({
    this.padding = AppSpacing.md,
    this.semanticsLabel,
    super.key,
  });

  final double padding;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FixSkeletonIdentity(),
          SizedBox(height: AppSpacing.md),
          FixSkeletonLines(count: 2, lineHeight: 10),
        ],
      ),
    ),
  );
}

/// N cards, for a list that is loading.
class FixSkeletonList extends StatelessWidget {
  const FixSkeletonList({
    this.count = 4,
    this.spacing = AppSpacing.md,
    super.key,
  });

  final int count;
  final double spacing;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (_, _) => const FixSkeletonCard(),
    ),
  );
}

/// Chat bubbles, alternating sides, so the thread does not reflow sideways when
/// the messages arrive.
class FixSkeletonThread extends StatelessWidget {
  const FixSkeletonThread({
    this.count = 6,
    this.spacing = AppSpacing.sm,
    super.key,
  });

  final int count;
  final double spacing;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < count; index += 1)
          Padding(
            padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : spacing),
            child: Row(
              // Not FractionallySizedBox: a Row hands its child unbounded
              // width, so a fractional box there is asked to lay out against
              // infinite constraints and throws. Aligning the bubble inside an
              // Expanded gets the same result and survives a narrow screen.
              mainAxisAlignment: index.isEven
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              children: [
                Flexible(
                  child: FractionallySizedBox(
                    alignment: index.isEven
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    widthFactor: index.isEven ? 0.62 : 0.44,
                    child: FixSkeleton(
                      height: 34,
                      radius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// A block that announces itself and shows a spinner.
///
/// This is the honest choice for two cases the skeletons do not cover: work whose
/// duration is genuinely unknown (generating a diagnosis, an AI answer), and a
/// small region where a spinner is less disruptive than a shimmer that keeps
/// moving. MOB-005 replaced the content spinners with skeletons; it did not
/// replace these, because removing the spinner from an upload or a GPS fix
/// removes the only feedback that the action is still running.
class FixLoadingBlock extends StatelessWidget {
  const FixLoadingBlock({
    this.label = 'Loading',
    this.padding = AppSpacing.xl,
    this.child,
    super.key,
  });

  final String label;
  final double padding;

  /// A shaped skeleton to show inside the announced region, when there is a
  /// known shape. Null falls back to a spinner.
  final Widget? child;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child:
            child ??
            const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading'),
            ),
      ),
    ),
  );
}

class _FixStateView extends StatelessWidget {
  const _FixStateView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (actionLabel case final label?) ...[
            const SizedBox(height: AppSpacing.xl),
            FixButton(
              label: label,
              onPressed: onAction,
              variant: FixButtonVariant.secondary,
            ),
          ],
        ],
      ),
    ),
  );
}
