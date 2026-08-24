import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/ratings/booking_review.dart';
import 'package:fixnow_mobile/features/ratings/review_photo.dart';
import 'package:file_picker/file_picker.dart';
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
  List<ReviewPhoto> _photos = const [];
  int? _rating;
  bool _loading = true;
  bool _submitting = false;
  bool _photoBusy = false;
  String? _error;
  String? _photoError;

  Future<void> _reloadPhotos() async {
    try {
      final photos = await widget.repository.reviewPhotos(widget.booking.id);
      if (mounted) setState(() => _photos = photos);
    } catch (_) {
      // The photo section keeps its last honest state on refresh failure.
    }
  }

  /// FN-110: pick and attach up to three bounded review photos.
  Future<void> _attachPhoto() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      final file = result?.files.single;
      if (file?.bytes == null) return;
      final extension = file!.extension?.toLowerCase();
      if (file.bytes!.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) {
          setState(
            () => _photoError =
                'That photo is over 5 MB. Choose a smaller one.',
          );
        }
        return;
      }
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      await widget.repository.attachReviewPhoto(
        bookingId: widget.booking.id,
        contentType: contentType,
        bytes: file.bytes!,
      );
      await _reloadPhotos();
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoError =
              'The photo could not be added. Use a JPG, PNG, or WebP under 5 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

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
      final photos = review == null
          ? const <ReviewPhoto>[]
          : await widget.repository.reviewPhotos(widget.booking.id);
      if (mounted)
        setState(() {
          _review = review;
          _photos = photos;
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
            ...[
              const SizedBox(height: AppSpacing.md),
              _ReviewPhotosSection(
                photos: _photos,
                photoBusy: _photoBusy,
                photoError: _photoError,
                onChanged: _reloadPhotos,
                onAttach: _attachPhoto,
              ),
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

/// FN-110: bounded review-photo attachment with honest moderation states.
/// Photos are never publicly visible until moderation approves them.
class _ReviewPhotosSection extends StatelessWidget {
  const _ReviewPhotosSection({
    required this.photos,
    required this.photoBusy,
    required this.photoError,
    required this.onChanged,
    required this.onAttach,
  });
  final List<ReviewPhoto> photos;
  final bool photoBusy;
  final String? photoError;
  final VoidCallback onChanged;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < 3 && photoBusy == false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos (optional)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        for (final photo in photos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  switch (photo.status) {
                    'APPROVED' => Icons.check_circle_outline_rounded,
                    'REJECTED' => Icons.cancel_outlined,
                    _ => Icons.hourglass_top_rounded,
                  },
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    switch (photo.status) {
                      'APPROVED' => 'Visible on your review',
                      'REJECTED' => 'Not published after moderation',
                      _ => 'Awaiting a moderation check before it is shown',
                    },
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (photoError case final message?) Text(message),
        if (canAdd)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAttach,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add photo'),
            ),
          ),
      ],
    );
  }
}
