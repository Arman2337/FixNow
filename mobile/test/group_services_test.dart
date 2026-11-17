import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/group_services/group_services_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts a shared URL, the native URL and a manually pasted token', () {
    final token = 'a' * 48;
    expect(
      groupInviteToken(
        'https://fixnow.example/api/v1/group-services/invite#$token',
      ),
      token,
    );
    expect(groupInviteToken('fixnow://group-invite/$token'), token);
    expect(groupInviteToken(' $token '), token);
    expect(groupInviteToken('https://fixnow.example/other#$token'), isNull);
    expect(groupInviteToken('fixnow://other/$token'), isNull);
  });

  testWidgets('organizer compares quotes and confirms the selected provider', (
    tester,
  ) async {
    final api = _GroupApi();
    await tester.pumpWidget(
      MaterialApp(
        home: GroupServicesScreen(
          api: api,
          accessToken: () async => 'test-token',
          baseUri: Uri.parse('https://fixnow.example/api/v1/'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AC cleaning'));
    await tester.pumpAndSettle();

    expect(find.text('Save ₹250.00 per household'), findsOneWidget);
    expect(find.text('Identity verified'), findsOneWidget);
    final select = find
        .widgetWithText(FilledButton, 'Select this provider')
        .first;
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();
    expect(find.text('Select Cool Air?'), findsOneWidget);
    expect(api.selection, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Select provider'));
    await tester.pumpAndSettle();
    expect(api.selection, 'quote-1');
    expect(find.text('Selected quote'), findsOneWidget);
    expect(find.text('Select this provider'), findsNothing);
  });
}

class _GroupApi implements ApiTransport {
  String? selection;
  Map<String, Object?> get group => {
    'id': 'group-1',
    'service': 'AC cleaning',
    'area': 'Indiranagar',
    'description': 'One split AC per household',
    'memberCount': 2,
    'requestedAt': '2026-11-05T00:00:00.000Z',
    'selectedQuoteId': selection,
    'organizer': true,
  };

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final Object body;
    switch (request.path) {
      case 'group-services':
        body = [group];
      case 'group-services/group-1':
        body = {
          ...group,
          'quotes': [
            {
              'id': 'quote-1',
              'providerName': 'Cool Air',
              'regularMinor': 100000,
              'groupMinor': 75000,
              'verified': true,
              'note': 'Filter and coil cleaning',
            },
            {
              'id': 'quote-2',
              'providerName': 'Quick Service',
              'regularMinor': 100000,
              'groupMinor': 90000,
              'verified': false,
              'note': 'Filter cleaning',
            },
          ],
        };
      case 'group-services/group-1/select':
        selection = request.body!['quoteId'] as String;
        body = {'id': 'group-1'};
      default:
        throw StateError('Unexpected path ${request.path}');
    }
    return ApiResponse(statusCode: 200, body: body);
  }
}
