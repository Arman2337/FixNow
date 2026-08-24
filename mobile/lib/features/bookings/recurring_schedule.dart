import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:flutter/foundation.dart';

/// FN-112: a repeating service schedule. Occurrences never book silently;
/// the customer confirms each upcoming visit explicitly.
class RecurringSchedule {
  const RecurringSchedule({
    required this.id,
    required this.serviceCategoryId,
    required this.description,
    required this.cadence,
    required this.status,
    required this.nextOccurrenceAt,
  });
  final String id;
  final String serviceCategoryId;
  final String description;
  final String cadence;
  final String status;
  final DateTime? nextOccurrenceAt;

  factory RecurringSchedule.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final category = json['serviceCategoryId'];
    final description = json['description'];
    final cadence = json['cadence'];
    final status = json['status'];
    if (id is! String ||
        category is! String ||
        description is! String ||
        cadence is! String ||
        status is! String) {
      throw const FormatException();
    }
    return RecurringSchedule(
      id: id,
      serviceCategoryId: category,
      description: description,
      cadence: cadence,
      status: status,
      nextOccurrenceAt: json['nextOccurrenceAt'] == null
          ? null
          : DateTime.tryParse(json['nextOccurrenceAt'].toString()),
    );
  }

  bool get isActive => status == 'ACTIVE';
}

enum SchedulesStatus { initial, loading, ready, empty, offline, error }

class SchedulesController extends ChangeNotifier {
  SchedulesController(this._repository);
  final BookingRepository _repository;
  SchedulesStatus status = SchedulesStatus.initial;
  List<RecurringSchedule> schedules = const [];
  bool working = false;
  String? errorMessage;

  Future<void> load() async {
    status = status == SchedulesStatus.ready
        ? SchedulesStatus.ready
        : SchedulesStatus.loading;
    notifyListeners();
    try {
      final rows = await _repository.schedules();
      schedules = rows;
      status = rows.isEmpty ? SchedulesStatus.empty : SchedulesStatus.ready;
    } on ApiException catch (error) {
      status = error.kind == ApiFailureKind.offline ||
              error.kind == ApiFailureKind.timeout
          ? SchedulesStatus.offline
          : SchedulesStatus.error;
    } catch (_) {
      status = SchedulesStatus.error;
    }
    notifyListeners();
  }

  /// Confirms the next occurrence; returns the created booking id so the
  /// caller can surface it through normal booking flows.
  Future<String?> confirm(RecurringSchedule schedule) =>
      _run(() => _repository.confirmSchedule(schedule.id));

  Future<void> updateStatus(RecurringSchedule schedule, String action) =>
      _run(
        () => _repository.scheduleAction(schedule.id, action),
        reloadAfter: true,
      );

  Future<String?> _run(
    Future<Map<String, Object?>> Function() action, {
    bool reloadAfter = false,
  }) async {
    working = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await action();
      if (reloadAfter) await load();
      return ((result['booking'] as Map?)?['id'])?.toString();
    } on ApiException catch (error) {
      errorMessage = error.statusCode == 409
          ? 'That visit time just changed. Refresh and try again.'
          : 'We could not complete that. Check your connection and retry.';
    } catch (_) {
      errorMessage = 'We could not complete that. Try again.';
    } finally {
      working = false;
      notifyListeners();
    }
    return null;
  }
}
