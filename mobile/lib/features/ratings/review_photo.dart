/// FN-110: a photo attached to a review. Photos stay hidden from everyone
/// but the author until moderation approves them.
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
}
