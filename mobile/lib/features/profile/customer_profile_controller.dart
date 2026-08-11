import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_repository.dart';
import 'package:flutter/foundation.dart';

enum ProfileViewStatus {
  initial,
  loading,
  ready,
  saving,
  saved,
  offline,
  unauthorized,
  error,
}

class CustomerProfileController extends ChangeNotifier {
  CustomerProfileController(this._repository);
  final CustomerProfileRepository _repository;
  ProfileViewStatus status = ProfileViewStatus.initial;
  String displayName = '';

  Future<void> load() async {
    status = ProfileViewStatus.loading;
    notifyListeners();
    try {
      displayName = (await _repository.read()).displayName ?? '';
      status = ProfileViewStatus.ready;
    } on ApiException catch (error) {
      status = _map(error);
    } catch (_) {
      status = ProfileViewStatus.error;
    }
    notifyListeners();
  }

  Future<bool> save(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 80 ||
        trimmed.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      return false;
    }
    status = ProfileViewStatus.saving;
    notifyListeners();
    try {
      displayName = (await _repository.update(trimmed)).displayName ?? '';
      status = ProfileViewStatus.saved;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      status = _map(error);
    } catch (_) {
      status = ProfileViewStatus.error;
    }
    notifyListeners();
    return false;
  }

  ProfileViewStatus _map(ApiException error) => switch (error.kind) {
    ApiFailureKind.offline ||
    ApiFailureKind.timeout => ProfileViewStatus.offline,
    ApiFailureKind.unauthorized => ProfileViewStatus.unauthorized,
    _ => ProfileViewStatus.error,
  };
}
