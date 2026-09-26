import 'package:flutter/foundation.dart';
import 'complaint.dart';

enum ComplaintsListStatus { initial, loading, ready, empty, offline, error }

enum SubmitComplaintStatus { initial, submitting, success, error }

class ComplaintsController extends ChangeNotifier {
  ComplaintsController(this._repository);
  final ComplaintsRepository _repository;

  ComplaintsListStatus listStatus = ComplaintsListStatus.initial;
  List<Complaint> complaints = const [];
  String? listError;

  SubmitComplaintStatus submitStatus = SubmitComplaintStatus.initial;
  String? submitError;
  bool proofSubmitting = false;
  bool callbackSubmitting = false;
  String? actionError;

  Future<void> loadComplaints() async {
    listStatus = ComplaintsListStatus.loading;
    listError = null;
    notifyListeners();

    try {
      complaints = await _repository.listComplaints();
      listStatus = complaints.isEmpty
          ? ComplaintsListStatus.empty
          : ComplaintsListStatus.ready;
    } catch (e) {
      listStatus = ComplaintsListStatus.error;
      listError = e.toString();
    }
    notifyListeners();
  }

  Future<Complaint?> submitComplaint({
    String? bookingId,
    required String targetRole,
    String? targetId,
    required String category,
    required String description,
  }) async {
    submitStatus = SubmitComplaintStatus.submitting;
    submitError = null;
    notifyListeners();

    try {
      final complaint = await _repository.submitComplaint(
        bookingId: bookingId,
        targetRole: targetRole,
        targetId: targetId,
        category: category,
        description: description,
      );
      submitStatus = SubmitComplaintStatus.success;
      complaints = [complaint, ...complaints];
      if (listStatus == ComplaintsListStatus.empty) {
        listStatus = ComplaintsListStatus.ready;
      }
      notifyListeners();
      return complaint;
    } catch (e) {
      submitStatus = SubmitComplaintStatus.error;
      submitError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> addEvidence(
    String complaintId, {
    required String fileUrl,
    required String fileType,
    String? description,
  }) async {
    proofSubmitting = true;
    actionError = null;
    notifyListeners();
    try {
      final updated = await _repository.addEvidence(
        complaintId,
        fileUrl: fileUrl,
        fileType: fileType,
        description: description,
      );
      _replaceComplaint(updated);
      return true;
    } catch (error) {
      actionError = error.toString();
      return false;
    } finally {
      proofSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> requestCallback(String complaintId) async {
    callbackSubmitting = true;
    actionError = null;
    notifyListeners();
    try {
      final updated = await _repository.requestCallback(complaintId);
      _replaceComplaint(updated);
      return true;
    } catch (error) {
      actionError = error.toString();
      return false;
    } finally {
      callbackSubmitting = false;
      notifyListeners();
    }
  }

  void _replaceComplaint(Complaint updated) {
    complaints = [
      for (final complaint in complaints)
        if (complaint.id == updated.id) updated else complaint,
    ];
  }

  void resetSubmitStatus() {
    submitStatus = SubmitComplaintStatus.initial;
    submitError = null;
    notifyListeners();
  }
}
