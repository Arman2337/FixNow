import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:flutter/foundation.dart';

/// FN-143. Which side of the job a photograph shows. The backend stores
/// exactly one of each per booking, and the customer's slider is a before/after
/// comparison — so this is a closed set, not a label.
enum JobProofStage {
  before('BEFORE', 'Before'),
  after('AFTER', 'After');

  const JobProofStage(this.wireValue, this.label);

  /// The token the backend's `stage` CHECK constraint accepts.
  final String wireValue;

  /// Plain-language label for the customer.
  final String label;

  static JobProofStage? parse(String? raw) {
    for (final stage in JobProofStage.values) {
      if (stage.wireValue == raw) return stage;
    }
    return null;
  }
}

/// One stored job-proof photograph, as the API describes it.
///
/// Carries no storage key: the backend never sends one, and the bytes are
/// fetched through a participant-checked endpoint rather than assembled from a
/// URL here.
class JobProofPhoto {
  const JobProofPhoto({
    required this.id,
    required this.bookingId,
    required this.stage,
    required this.contentType,
    required this.sizeBytes,
    this.capturedAt,
  });

  final String id;
  final String bookingId;
  final JobProofStage stage;
  final String contentType;
  final int sizeBytes;
  final DateTime? capturedAt;

  factory JobProofPhoto.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final bookingId = json['bookingId'];
    final stage = JobProofStage.parse(json['stage']?.toString());
    if (id is! String || bookingId is! String || stage == null) {
      throw const FormatException();
    }
    return JobProofPhoto(
      id: id,
      bookingId: bookingId,
      stage: stage,
      contentType: json['contentType']?.toString() ?? 'image/jpeg',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      capturedAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

enum JobProofStatus {
  /// Nothing has been asked for yet.
  initial,

  loading,

  /// Both sides are present and rendered.
  ready,

  /// The provider has captured nothing for this booking.
  none,

  /// Exactly one side exists. The panel must say which, rather than showing an
  /// empty half and letting the customer assume the work was never recorded.
  partial,

  /// The read failed. Distinct from [none] so a connection problem never reads
  /// as "your pro took no photos".
  error,
}

/// FN-143. Reads and writes the before/after proof for one booking.
class JobProofController extends ChangeNotifier {
  JobProofController(this._repository, {this.downloader});

  final BookingRepository _repository;

  /// Null when the transport cannot fetch bytes; the panel then says the photo
  /// is unavailable rather than rendering an empty frame that looks like a
  /// photo the provider never took.
  final BinaryDownloader? downloader;

  JobProofStatus status = JobProofStatus.initial;
  String? bookingId;
  Uint8List? beforeBytes;
  Uint8List? afterBytes;
  DateTime? beforeCapturedAt;
  DateTime? afterCapturedAt;
  String? message;

  bool get hasBefore => beforeBytes != null;
  bool get hasAfter => afterBytes != null;
  bool get isBusy => status == JobProofStatus.loading;

  /// Which side is missing, phrased for a customer.
  String? get missingSideLabel => switch (status) {
    JobProofStatus.partial when !hasBefore => 'before',
    JobProofStatus.partial when !hasAfter => 'after',
    _ => null,
  };

  Future<void> load(String id) async {
    bookingId = id;
    status = JobProofStatus.loading;
    message = null;
    beforeBytes = null;
    afterBytes = null;
    beforeCapturedAt = null;
    afterCapturedAt = null;
    notifyListeners();
    try {
      final photos = await _repository.jobProofPhotos(id);
      if (photos.isEmpty) {
        status = JobProofStatus.none;
        notifyListeners();
        return;
      }
      final downloader = this.downloader;
      final bytes = <JobProofStage, Uint8List>{};
      for (final photo in photos) {
        if (downloader == null) continue;
        try {
          bytes[photo.stage] = await _repository.jobProofBytes(
            id,
            photo.id,
            downloader,
          );
        } on ApiException {
          // One unreadable side must not erase the other: a customer can still
          // see the half that loaded, and the panel names what is missing.
        }
      }
      final before = bytes[JobProofStage.before];
      final after = bytes[JobProofStage.after];
      beforeBytes = before;
      afterBytes = after;
      beforeCapturedAt = photos
          .where((photo) => photo.stage == JobProofStage.before)
          .map((photo) => photo.capturedAt)
          .firstWhere((value) => value != null, orElse: () => null);
      afterCapturedAt = photos
          .where((photo) => photo.stage == JobProofStage.after)
          .map((photo) => photo.capturedAt)
          .firstWhere((value) => value != null, orElse: () => null);
      status = (before == null || after == null)
          ? JobProofStatus.partial
          : JobProofStatus.ready;
    } on ApiException catch (error) {
      status = JobProofStatus.error;
      message = switch (error.kind) {
        ApiFailureKind.offline || ApiFailureKind.timeout =>
          'Job photos could not be loaded. Check your connection and try again.',
        ApiFailureKind.unauthorized => 'Sign in to view job photos.',
        _ => 'Job photos are unavailable right now.',
      };
    } catch (_) {
      status = JobProofStatus.error;
      message = 'Job photos are unavailable right now.';
    }
    notifyListeners();
  }

  /// Upload one side. Returns null on success or a safe message on failure —
  /// never a raw backend error, per DESIGN.md §27.
  Future<String?> capture({
    required String id,
    required JobProofStage stage,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await _repository.captureJobProof(
        bookingId: id,
        stage: stage,
        bytes: bytes,
        contentType: contentType,
      );
      await load(id);
      return null;
    } on ApiException catch (error) {
      return switch (error.kind) {
        ApiFailureKind.offline || ApiFailureKind.timeout =>
          'The photo was not uploaded. Check your connection and try again.',
        ApiFailureKind.unauthorized => 'Sign in to upload job photos.',
        _ => 'The photo was not uploaded.',
      };
    } catch (_) {
      return 'The photo was not uploaded.';
    }
  }
}