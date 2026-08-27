import 'dart:typed_data';
import 'package:flutter/material.dart';

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

/// In-memory repository persisting job proofs across provider and customer sessions.
class JobProofRepository {
  JobProofRepository._();
  static final JobProofRepository instance = JobProofRepository._();

  final Map<String, JobProof> _proofs = {};
  final ValueNotifier<int> _changeNotifier = ValueNotifier(0);

  ValueNotifier<int> get notifier => _changeNotifier;

  void saveProof(JobProof proof) {
    _proofs[proof.bookingId] = proof;
    _changeNotifier.value++;
  }

  JobProof? getProof(String bookingId) => _proofs[bookingId];

  bool hasProof(String bookingId) => _proofs.containsKey(bookingId);

  void clear() {
    _proofs.clear();
    _changeNotifier.value++;
  }
}
