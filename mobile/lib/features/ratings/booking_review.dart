class BookingReview {
  const BookingReview({
    required this.id,
    required this.rating,
    required this.reviewText,
    required this.moderationStatus,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String? reviewText;
  final String moderationStatus;
  final DateTime createdAt;

  factory BookingReview.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final rating = json['rating'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (id is! String || rating is! num || createdAt == null) {
      throw const FormatException();
    }
    return BookingReview(
      id: id,
      rating: rating.toInt(),
      reviewText: json['reviewText'] as String?,
      moderationStatus: json['moderationStatus']?.toString() ?? 'PUBLISHED',
      createdAt: createdAt,
    );
  }
}
