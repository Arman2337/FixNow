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
    await tester.scrollUntilVisible(
      select,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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

  testWidgets(
    'joined approved customer can share invite link and track status; organizer approves requests',
    (tester) async {
      final api = _ApprovalGroupApi();
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

      // Open as organizer to approve a pending member.
      await tester.tap(find.text('Plumbing'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Pending join requests (1)'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pending join requests (1)'), findsOneWidget);
      expect(find.text('Ravi Patel'), findsOneWidget);
      final accept = find.widgetWithText(FilledButton, 'Accept');
      await tester.scrollUntilVisible(
        accept,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(api.approvedCustomerId, 'cust-2');

      // Now inspect detail as an approved joined member (not organizer):
      api.isOrganizer = false;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Share invitation'), findsOneWidget);
      expect(find.text('Request group quotes'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Service status timeline'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Service status timeline'), findsOneWidget);
    },
  );

  testWidgets(
    'provider sees organizer info, household service addresses, and can update status',
    (tester) async {
      final api = _ProviderGroupApi();
      await tester.pumpWidget(
        MaterialApp(
          home: GroupServicesScreen(
            api: api,
            provider: true,
            accessToken: () async => 'test-token',
            baseUri: Uri.parse('https://fixnow.example/api/v1/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Organizer: Acceptance Customer A'), findsOneWidget);
      expect(find.text('Preferred schedule: Sunday 10 AM'), findsOneWidget);
      expect(
        find.text('Primary service address: Flat 201, Palm Residency, Anand'),
        findsOneWidget,
      );
      expect(find.textContaining('Flat 202, Palm Residency'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Mark scheduled'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Mark scheduled'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Mark scheduled').last);
      await tester.pumpAndSettle();
      expect(api.updatedStatus, 'SCHEDULED');
    },
  );
}

class _ApprovalGroupApi implements ApiTransport {
  String? approvedCustomerId;
  bool isOrganizer = true;

  Map<String, Object?> get _group => {
    'id': 'group-2',
    'service': 'Plumbing',
    'area': 'Vidyanagar',
    'serviceAddress': 'B-12, Lotus Enclave, Anand',
    'preferredSchedule': 'Saturday Morning',
    'description': 'Overhead tank cleaning for 3 flats',
    'memberCount': approvedCustomerId == null ? 1 : 2,
    'requestedAt': null,
    'selectedQuoteId': null,
    'serviceStatus': 'INVITING',
    'organizer': isOrganizer,
    'organizerName': 'Organizer Patel',
    'membershipStatus': 'approved',
    'inviteToken': 'b' * 48,
  };

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    switch (request.path) {
      case 'group-services':
        return ApiResponse(statusCode: 200, body: [_group]);
      case 'group-services/group-2':
        return ApiResponse(
          statusCode: 200,
          body: {
            ..._group,
            'quotes': const [],
            'members': [
              {
                'customerId': 'cust-1',
                'displayName': 'Organizer Patel',
                'serviceAddress': 'B-12, Lotus Enclave, Anand',
                'status': 'approved',
                'organizer': true,
              },
              {
                'customerId': 'cust-2',
                'displayName': 'Ravi Patel',
                'serviceAddress': 'B-14, Lotus Enclave, Anand',
                'status': approvedCustomerId == 'cust-2'
                    ? 'approved'
                    : 'pending',
                'organizer': false,
              },
            ],
          },
        );
      case 'group-services/group-2/members/cust-2/approve':
        approvedCustomerId = 'cust-2';
        return const ApiResponse(
          statusCode: 200,
          body: {'groupId': 'group-2', 'customerId': 'cust-2', 'status': 'approved'},
        );
      default:
        throw StateError('Unexpected path ${request.path}');
    }
  }
}

class _ProviderGroupApi implements ApiTransport {
  String serviceStatus = 'PROVIDER_SELECTED';
  String? updatedStatus;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    switch (request.path) {
      case 'group-services/provider':
        return ApiResponse(
          statusCode: 200,
          body: [
            {
              'id': 'group-3',
              'service': 'AC cleaning',
              'area': 'Anand',
              'serviceAddress': 'Flat 201, Palm Residency, Anand',
              'preferredSchedule': 'Sunday 10 AM',
              'description': 'Split AC servicing for two flats',
              'memberCount': 2,
              'organizerName': 'Acceptance Customer A',
              'organizerPhone': '+919000000101',
              'requestedAt': '2026-11-20T09:00:00Z',
              'ownQuoteId': 'quote-1',
              'ownGroupMinor': 75000,
              'ownRegularMinor': 100000,
              'ownNote': 'Gas check included',
              'selectedQuoteId': 'quote-1',
              'serviceStatus': serviceStatus,
              'members': [
                {
                  'customerId': 'cust-1',
                  'displayName': 'Acceptance Customer A',
                  'serviceAddress': 'Flat 201, Palm Residency, Anand',
                  'phone': '+919000000101',
                  'status': 'approved',
                  'organizer': true,
                },
                {
                  'customerId': 'cust-2',
                  'displayName': 'Neha Shah',
                  'serviceAddress': 'Flat 202, Palm Residency, Anand',
                  'phone': '+919000000109',
                  'status': 'approved',
                  'organizer': false,
                },
              ],
            },
          ],
        );
      case 'group-services/group-3/status':
        updatedStatus = request.body!['status'] as String;
        serviceStatus = updatedStatus!;
        return ApiResponse(
          statusCode: 200,
          body: {'id': 'group-3', 'serviceStatus': serviceStatus},
        );
      default:
        throw StateError('Unexpected path ${request.path}');
    }
  }
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
