import 'package:fixnow_mobile/api/api_client.dart';
import 'complaint.dart';

class ComplaintsRepository {
  const ComplaintsRepository({
    required ApiTransport client,
    required Future<String?> Function() accessToken,
  })  : _client = client,
        _accessToken = accessToken;
        
  final ApiTransport _client;
  final Future<String?> Function() _accessToken;

  Future<String> _requireToken() async {
    final token = await _accessToken();
    if (token == null) {
      throw const ApiException(ApiFailureKind.unauthorized, 'Not signed in');
    }
    return token;
  }

  Future<Complaint> submitComplaint({
    String? bookingId,
    required String targetRole,
    String? targetId,
    required String category,
    required String description,
  }) async {
    final token = await _requireToken();
    final response = await _client.send(ApiRequest(
      method: ApiMethod.post,
      path: 'support/complaints',
      bearerToken: token,
      body: {
        if (bookingId != null) 'bookingId': bookingId,
        'targetRole': targetRole,
        if (targetId != null) 'targetId': targetId,
        'category': category,
        'description': description,
      },
    ));
    return Complaint.fromJson(response.body as Map<String, dynamic>);
  }

  Future<List<Complaint>> listComplaints() async {
    final token = await _requireToken();
    final response = await _client.send(ApiRequest(
      method: ApiMethod.get,
      path: 'support/complaints',
      bearerToken: token,
    ));
    final list = response.body as List<dynamic>;
    return list.map((e) => Complaint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Complaint> getComplaint(String id) async {
    final token = await _requireToken();
    final response = await _client.send(ApiRequest(
      method: ApiMethod.get,
      path: 'support/complaints/$id',
      bearerToken: token,
    ));
    return Complaint.fromJson(response.body as Map<String, dynamic>);
  }
}
