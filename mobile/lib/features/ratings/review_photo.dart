/// FN-110: a photo attached to a review. Photos stay hidden from everyone
/// but the author until moderation approves them.
///
/// FN-144: the projection carries no image reference, by design — the backend
/// never exposes `objectKey`. The bytes come from the participant-checked
/// content endpoint instead, so there is nothing here to leak.
class ReviewPhoto {
  const ReviewPhoto({required this.id, required this.status});

  final String id;
  final String status;

  factory ReviewPhoto.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final status = json['status'];
    if (id is! String || status is! String) {
      throw const FormatException();
    }
    return ReviewPhoto(id: id, status: status);
  }

  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  /// Whether this actor may fetch the bytes.
  ///
  /// The server re-checks this, so it is a UI affordance and not the
  /// enforcement point: a pending photo is shown as awaiting moderation rather
  /// than as a broken image, and a rejected one is not offered at all.
  bool get canBeViewed => isApproved || status == 'PENDING';
}
