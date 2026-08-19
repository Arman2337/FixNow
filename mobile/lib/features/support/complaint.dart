export 'complaints_repository.dart';
export 'complaints_controller.dart';
export 'submit_complaint_screen.dart';

class Complaint {
  const Complaint({
    required this.id,
    this.bookingId,
    required this.submitterId,
    required this.targetRole,
    this.targetId,
    this.assigneeId,
    required this.category,
    required this.description,
    required this.status,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? bookingId;
  final String submitterId;
  final String targetRole;
  final String? targetId;
  final String? assigneeId;
  final String category;
  final String description;
  final String status;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as String,
        bookingId: json['bookingId'] as String?,
        submitterId: json['submitterId'] as String,
        targetRole: json['targetRole'] as String,
        targetId: json['targetId'] as String?,
        assigneeId: json['assigneeId'] as String?,
        category: json['category'] as String,
        description: json['description'] as String,
        status: json['status'] as String,
        resolutionNotes: json['resolutionNotes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class ComplaintEvidence {
  const ComplaintEvidence({
    required this.id,
    required this.fileUrl,
    required this.fileType,
    this.description,
  });

  final String id;
  final String fileUrl;
  final String fileType;
  final String? description;

  factory ComplaintEvidence.fromJson(Map<String, dynamic> json) =>
      ComplaintEvidence(
        id: json['id'] as String,
        fileUrl: json['fileUrl'] as String,
        fileType: json['fileType'] as String,
        description: json['description'] as String?,
      );
}
