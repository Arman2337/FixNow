import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/foundation.dart';

abstract interface class ServiceCategoryRepository {
  Future<List<ServiceCategory>> active();
}

class ApiServiceCategoryRepository implements ServiceCategoryRepository {
  const ApiServiceCategoryRepository(this._api);
  final ApiTransport _api;

  @override
  Future<List<ServiceCategory>> active() async {
    final response = await _api.send(
      const ApiRequest(
        method: ApiMethod.get,
        path: 'service-categories/active',
      ),
    );
    final items = response.body;
    if (items is! List) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'The service list was invalid.',
      );
    }
    return items
        .map((item) {
          if (item is! Map<String, dynamic>) throw const FormatException();
          return ServiceCategory.fromJson(item);
        })
        .toList(growable: false);
  }
}

enum DiscoveryStatus { initial, loading, ready, empty, offline, error }

class ServiceDiscoveryController extends ChangeNotifier {
  ServiceDiscoveryController(this._repository);
  final ServiceCategoryRepository _repository;
  DiscoveryStatus status = DiscoveryStatus.initial;
  List<ServiceCategory> categories = const [];

  Future<void> load() async {
    status = DiscoveryStatus.loading;
    notifyListeners();
    try {
      categories = await _repository.active();
      status = categories.isEmpty
          ? DiscoveryStatus.empty
          : DiscoveryStatus.ready;
    } on ApiException catch (error) {
      status =
          error.kind == ApiFailureKind.offline ||
              error.kind == ApiFailureKind.timeout
          ? DiscoveryStatus.offline
          : DiscoveryStatus.error;
    } catch (_) {
      status = DiscoveryStatus.error;
    }
    notifyListeners();
  }
}
