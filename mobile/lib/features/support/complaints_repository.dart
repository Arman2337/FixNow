import 'package:fixnow_mobile/api/api_client.dart';
import 'complaint.dart';

class ComplaintsRepository {
  const ComplaintsRepository(this._client);
  final ApiTransport _client;

  Future<Complaint> submitComplaint({
    String? bookingId,
    required String targetRole,
    String? targetId,
    required String category,
    required String description,
  }) async {
    final response = await _client.send(ApiRequest(
      method: ApiMethod.post,
      path: '/support/complaints',
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
    final response = await _client.send(const ApiRequest(
      method: ApiMethod.get,
      path: '/support/complaints',
    ));
    final list = response.body as List<dynamic>;
    return list.map((e) => Complaint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Complaint> getComplaint(String id) async {
    final response = await _client.send(ApiRequest(
      method: ApiMethod.get,
      path: '/support/complaints/$id',
    ));
    return Complaint.fromJson(response.body as Map<String, dynamic>);
  }
}
