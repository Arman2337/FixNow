import 'dart:typed_data';

/// Holds tamper-proof before and after work photos captured by the technician.
class JobProof {
  const JobProof({
    required this.bookingId,
    this.beforePhotoBytes,
    this.beforePhotoName,
    this.afterPhotoBytes,
    this.afterPhotoName,
    this.notes,
    required this.capturedAt,
    this.proName = 'Verified Pro',
  });

  final String bookingId;
  final Uint8List? beforePhotoBytes;
  final String? beforePhotoName;
  final Uint8List? afterPhotoBytes;
  final String? afterPhotoName;
  final String? notes;
  final DateTime capturedAt;
  final String proName;

  bool get hasBeforePhoto =>
      beforePhotoBytes != null && beforePhotoBytes!.isNotEmpty;

  bool get hasAfterPhoto =>
      afterPhotoBytes != null && afterPhotoBytes!.isNotEmpty;

  bool get isComplete => hasBeforePhoto && hasAfterPhoto;
}

/// FN-142 shipped the server-side pipeline. FN-143 removed the in-memory
/// `JobProofRepository` that used to stand in for it: it only ever held photos
/// captured by the provider in the same process, so a customer on a different
/// device saw nothing and the proof never survived a restart. Anything still
/// needing the old behaviour should be reading `JobProofController`.
