import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/ratings/booking_review.dart';
import 'package:flutter/material.dart';

class BookingReviewPanel extends StatefulWidget {
  const BookingReviewPanel({
    required this.booking,
    required this.repository,
    super.key,
  });
  final CustomerBooking booking;
  final BookingRepository repository;

  @override
  State<BookingReviewPanel> createState() => _BookingReviewPanelState();
}

class _BookingReviewPanelState extends State<BookingReviewPanel> {
  final _text = TextEditingController();
  BookingReview? _review;
  int? _rating;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await widget.repository.reviewFor(widget.booking.id);
      if (mounted)
        setState(() {
          _review = review;
          _loading = false;
        });
    } on ApiException catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.kind == ApiFailureKind.offline
              ? 'You are offline. Reconnect to load your review.'
              : 'We could not load your review.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'We could not load your review.';
        });
    }
  }

  Future<void> _submit() async {
    if (_rating == null) {
      setState(() => _error = 'Choose a rating before submitting.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final review = await widget.repository.createReview(
        bookingId: widget.booking.id,
        rating: _rating!,
        reviewText: _text.text,
      );
      if (mounted)
        setState(() {
          _review = review;
          _submitting = false;
        });
    } on ApiException catch (error) {
      if (mounted)
        setState(() {
          _submitting = false;
          _error = error.kind == ApiFailureKind.offline
              ? 'You are offline. Your review was not sent.'
              : 'We could not submit your review. Try again.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _submitting = false;
          _error = 'We could not submit your review. Try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const FixCard(
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading review'),
        ),
      );
    if (_review case final review?)
      return FixCard(
        semanticLabel: 'Your submitted review',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thanks for your feedback',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${'★' * review.rating}${'☆' * (5 - review.rating)}',
              semanticsLabel: '${review.rating} out of 5 stars',
              style: const TextStyle(color: AppColors.accentGold, fontSize: 24),
            ),
            if (review.reviewText case final text?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(text),
            ],
          ],
        ),
      );
    return FixCard(
      semanticLabel: 'Rate this completed service',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How was your experience?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Your feedback is optional and helps us understand completed service quality.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            children: List.generate(5, (index) {
              final stars = index + 1;
              return Semantics(
                button: true,
                selected: _rating == stars,
                label: '$stars ${stars == 1 ? 'star' : 'stars'}',
                child: IconButton(
                  tooltip: '$stars ${stars == 1 ? 'star' : 'stars'}',
                  iconSize: 36,
                  color: AppColors.accentGold,
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _rating = stars),
                  icon: Icon(
                    (_rating ?? 0) >= stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _text,
            enabled: !_submitting,
            maxLength: 1000,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Optional feedback',
              hintText: 'Write a short review',
            ),
          ),
          if (_error case final message?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.sm),
          FixButton(
            label: 'Submit review',
            icon: Icons.send_rounded,
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
