import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/support/complaints_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds evidence through the complaint evidence endpoint', () async {
    final transport = _RecordingTransport();
    final repository = ComplaintsRepository(
      client: transport,
      accessToken: () async => 'token',
    );

    await repository.addEvidence(
      'complaint-1',
      fileUrl: 'https://example.test/proof.png',
      fileType: 'image',
      description: 'Meter reading',
    );

    expect(transport.requests.single.path, 'support/complaints/complaint-1/evidence');
    expect(transport.requests.single.method, ApiMethod.post);
    expect(transport.requests.single.body, {
      'fileUrl': 'https://example.test/proof.png',
      'fileType': 'image',
      'description': 'Meter reading',
    });
  });

  test('records a callback request through the complaint endpoint', () async {
    final transport = _RecordingTransport();
    final repository = ComplaintsRepository(
      client: transport,
      accessToken: () async => 'token',
    );

    await repository.requestCallback('complaint-1');

    expect(transport.requests.single.path, 'support/complaints/complaint-1/callback-request');
    expect(transport.requests.single.method, ApiMethod.post);
  });
}

class _RecordingTransport implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return const ApiResponse(
      statusCode: 200,
      body: {
        'id': 'complaint-1',
        'submitterId': 'user-1',
        'targetRole': 'PLATFORM',
        'category': 'Billing',
        'description': 'Invoice issue',
        'status': 'OPEN',
        'createdAt': '2026-09-24T10:00:00.000Z',
        'updatedAt': '2026-09-24T10:00:00.000Z',
        'evidence': [],
      },
    );
  }
}
