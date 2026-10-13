import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/data/last_good_cache.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/sub_service_item.dart';
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

/// FN-140. The key the service catalogue snapshot lives under.
const String kServiceCategoryCacheKey = 'service-categories';

class ServiceDiscoveryController extends ChangeNotifier {
  ServiceDiscoveryController(this._repository, this._subServiceRepository, {this.cache});
  final ServiceCategoryRepository _repository;
  final SubServiceRepository _subServiceRepository;

  /// FN-140: optional last-good store. Absent keeps the original online-only
  /// behaviour for every caller that does not pass one.
  final LastGoodCache? cache;

  DiscoveryStatus status = DiscoveryStatus.initial;
  List<ServiceCategory> categories = const [];
  List<SubServiceItem> allSubServices = const [];

  /// True when [categories] is a saved copy rather than a live server read.
  bool isShowingSavedData = false;

  /// When [categories] was last confirmed by the server. Null unless
  /// [isShowingSavedData].
  DateTime? savedDataAt;

  Future<void> load() async {
    status = DiscoveryStatus.loading;
    notifyListeners();
    try {
      categories = await _repository.active();
      try {
        allSubServices = await _subServiceRepository.getAllSubServices();
      } catch (_) {
        allSubServices = const [];
      }
      status = categories.isEmpty
          ? DiscoveryStatus.empty
          : DiscoveryStatus.ready;
      isShowingSavedData = false;
      savedDataAt = null;
      // Notify BEFORE touching storage: a slow or hanging disk must never hold
      // the catalogue off the screen.
      notifyListeners();
      await _saveSnapshot(categories);
      return;
    } on ApiException catch (error) {
      final restored = await _showSavedDataIfLostConnection(error);
      if (!restored) {
        status =
            error.kind == ApiFailureKind.offline ||
                error.kind == ApiFailureKind.timeout
            ? DiscoveryStatus.offline
            : DiscoveryStatus.error;
      }
    } catch (_) {
      final restored = await _showSavedDataIfLostConnection(
        const ApiException(ApiFailureKind.offline, 'No network connection.'),
      );
      if (!restored) status = DiscoveryStatus.error;
    }
    // One notify for every outcome: returning early from the saved-data path
    // would leave the screen on its skeleton with data that has arrived.
    notifyListeners();
  }

  /// FN-140: browse the last verified catalogue when the connection dropped.
  ///
  /// Only a transport failure qualifies. A server error, an auth failure or an
  /// unparseable body means the backend answered with something we cannot stand
  /// behind, and DESIGN.md §27 requires that to surface as an error rather than
  /// as a plausible-looking cached screen.
  Future<bool> _showSavedDataIfLostConnection(ApiException error) async {
    if (error.kind != ApiFailureKind.offline &&
        error.kind != ApiFailureKind.timeout) {
      return false;
    }
    final cache = this.cache;
    if (cache == null) return false;
    final snapshot = await cache.read(kServiceCategoryCacheKey);
    final data = snapshot?.data;
    if (snapshot == null || data is! List) return false;
    try {
      categories = data
          .map(
            (row) =>
                ServiceCategory.fromJson(Map<String, Object?>.from(row as Map)),
          )
          .toList(growable: false);
    } catch (_) {
      // A snapshot we cannot parse is not a snapshot we can show.
      return false;
    }
    status = categories.isEmpty
        ? DiscoveryStatus.empty
        : DiscoveryStatus.ready;
    isShowingSavedData = true;
    savedDataAt = snapshot.savedAt;
    return true;
  }

  Future<void> _saveSnapshot(List<ServiceCategory> latest) async {
    final cache = this.cache;
    if (cache == null) return;
    await cache.write(
      kServiceCategoryCacheKey,
      latest.map((category) => category.toJson()).toList(growable: false),
    );
  }
}
