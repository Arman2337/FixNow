import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/notifications/push_api.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTransport implements ApiTransport {
  FakeTransport({this.responses = const [], this.error});

  final List<ApiResponse> responses;
  final List<ApiRequest> requests = [];
  ApiException? error;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (error case final failure?) throw failure;
    if (responses.isEmpty) {
      return const ApiResponse(statusCode: 200, body: []);
    }
    return responses.removeAt(0);
  }
}

class FakeGateway implements PushGateway {
  FakeGateway({this.initialized = true, this.permissionGranted = true});

  bool initialized;
  bool permissionGranted;
  String? token = 'f' * 64;
  int permissionRequests = 0;

  @override
  Future<bool> ensureInitialized() async => initialized;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return permissionGranted;
  }

  @override
  Future<String?> currentToken() async => token;
}

PushEnrollmentController controllerFor(
  FakeTransport transport, [
  FakeGateway? gateway,
]) => PushEnrollmentController(
  api: PushApi(transport),
  gateway: gateway ?? FakeGateway(),
  featureEnabled: true,
);

void main() {
  test('stays fully inert when the build omits push support', () async {
    final transport = FakeTransport();
    final controller = PushEnrollmentController(
      api: PushApi(transport),
      gateway: FakeGateway(),
      featureEnabled: false,
    );
    expect(controller.status, PushEnrollmentStatus.disabled);
    await controller.refresh();
    await controller.enable();
    expect(transport.requests, isEmpty);
    expect(controller.status, PushEnrollmentStatus.disabled);
  });

  test('enable registers the device token with platform and lists devices', () async {
    final transport = FakeTransport(
      responses: [
        const ApiResponse(statusCode: 200, body: []),
        const ApiResponse(statusCode: 200, body: [
          {
            'id': 'device-1',
            'platform': 'ANDROID',
            'createdAt': '2026-08-24T00:00:00.000Z',
          },
        ]),
      ],
    );
    final controller = controllerFor(transport);
    await controller.enable();
    expect(controller.status, PushEnrollmentStatus.ready);
    expect(controller.devices.single.id, 'device-1');
    final registerRequest = transport.requests
        .firstWhere((request) => request.method == ApiMethod.put);
    expect(registerRequest.path, 'notifications/push/devices');
    expect(registerRequest.body, {
      'token': 'f' * 64,
      'platform': isNotEmpty,
    });
  });

  test('declined OS permission never contacts the backend', () async {
    final transport = FakeTransport();
    final controller = controllerFor(
      transport,
      FakeGateway(permissionGranted: false),
    );
    await controller.enable();
    expect(controller.status, PushEnrollmentStatus.permissionDenied);
    expect(
      transport.requests.where((request) => request.method == ApiMethod.put),
      isEmpty,
    );
  });

  test('uninitialized gateway reports unavailable without API calls', () async {
    final transport = FakeTransport();
    final controller = controllerFor(
      transport,
      FakeGateway(initialized: false),
    );
    await controller.refresh();
    expect(controller.status, PushEnrollmentStatus.unavailable);
    expect(transport.requests, isEmpty);
  });

  test('revoke deletes only the selected device and refreshes', () async {
    final transport = FakeTransport();
    final controller = controllerFor(transport);
    await controller.refresh();
    await controller.disable(
      PushDeviceSummary(
        id: 'device-9',
        platform: 'WEB',
        createdAt: DateTime.utc(2026, 8, 24),
      ),
    );
    expect(
      transport.requests.any(
        (request) =>
            request.method == ApiMethod.delete &&
            request.path == 'notifications/push/devices/device-9',
      ),
      isTrue,
    );
  });
}
