import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProviderTransport implements ApiTransport {
  Map<String, Object?>? lastPutBody;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.method == ApiMethod.put &&
        request.path == 'provider-availability/me/schedule') {
      lastPutBody = request.body?.cast<String, Object?>();
      return ApiResponse(
        statusCode: 200,
        body: {
          'status': 'offline',
          'version': 3,
          'timeZone': 'Asia/Kolkata',
          'weeklyRules': lastPutBody?['weeklyRules'] ?? [],
        },
      );
    }
    if (request.path == 'provider-applications/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {'status': 'approved'},
      );
    }
    if (request.path == 'provider-profile/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'displayName': 'Amina Services',
          'serviceRadiusKm': 15,
          'baseLatitude': 25.2,
          'baseLongitude': 55.3,
        },
      );
    }
    if (request.path == 'provider-availability/me') {
      return const ApiResponse(
        statusCode: 200,
        body: {
          'status': 'offline',
          'version': 2,
          'timeZone': 'Asia/Kolkata',
          'weeklyRules': [
            {
              'dayOfWeek': 1,
              'intervals': [
                {'startMinute': 600, 'endMinute': 1140},
              ],
            },
          ],
        },
      );
    }
    if (request.path == 'provider-skills/me' ||
        request.path == 'service-categories' ||
        request.path == 'provider-documents') {
      return const ApiResponse(statusCode: 200, body: <Object?>[]);
    }
    if (request.path.startsWith('bookings?') ||
        request.path.startsWith('bookings/available?')) {
      return const ApiResponse(
        statusCode: 200,
        body: {'bookings': <Object?>[], 'nextCursor': null},
      );
    }
    return const ApiResponse(statusCode: 200, body: <String, Object?>{});
  }
}

void main() {
  test('ProviderAvailability.scheduleSummary formats various schedules correctly', () {
    const empty = ProviderAvailability(
      status: 'offline',
      version: 1,
      timeZone: 'Asia/Kolkata',
      weeklyRules: [],
    );
    expect(empty.scheduleSummary, 'No recurring hours set.');

    const weekdays = ProviderAvailability(
      status: 'offline',
      version: 1,
      timeZone: 'Asia/Kolkata',
      weeklyRules: [
        {'dayOfWeek': 1, 'intervals': [{'startMinute': 540, 'endMinute': 1020}]},
        {'dayOfWeek': 2, 'intervals': [{'startMinute': 540, 'endMinute': 1020}]},
        {'dayOfWeek': 3, 'intervals': [{'startMinute': 540, 'endMinute': 1020}]},
        {'dayOfWeek': 4, 'intervals': [{'startMinute': 540, 'endMinute': 1020}]},
        {'dayOfWeek': 5, 'intervals': [{'startMinute': 540, 'endMinute': 1020}]},
      ],
    );
    expect(weekdays.scheduleSummary, 'Monday to Friday, 09:00–17:00 Asia/Kolkata');

    const monToSatCustom = ProviderAvailability(
      status: 'offline',
      version: 1,
      timeZone: 'Asia/Kolkata',
      weeklyRules: [
        {'dayOfWeek': 1, 'intervals': [{'startMinute': 600, 'endMinute': 1140}]},
        {'dayOfWeek': 2, 'intervals': [{'startMinute': 600, 'endMinute': 1140}]},
        {'dayOfWeek': 3, 'intervals': [{'startMinute': 600, 'endMinute': 1140}]},
        {'dayOfWeek': 4, 'intervals': [{'startMinute': 600, 'endMinute': 1140}]},
        {'dayOfWeek': 5, 'intervals': [{'startMinute': 600, 'endMinute': 1140}]},
        {'dayOfWeek': 6, 'intervals': [{'startMinute': 600, 'endMinute': 1140}]},
      ],
    );
    expect(monToSatCustom.scheduleSummary, 'Monday to Saturday, 10:00–19:00 Asia/Kolkata');
  });

  testWidgets('provider can open working hours sheet and save custom days and hours', (
    tester,
  ) async {
    final transport = _FakeProviderTransport();
    final controller = ProviderController(
      ProviderRepository(api: transport, accessToken: () async => 'token'),
    );
    await controller.load(verified: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ProviderHomeScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Working schedule'), findsOneWidget);
    expect(find.text('Edit schedule'), findsOneWidget);

    // Open sheet
    await tester.tap(find.text('Edit schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Working Days'), findsOneWidget);
    expect(find.text('Mon–Sat'), findsOneWidget);
    expect(find.text('10:00 – 19:00'), findsOneWidget);

    // Tap Mon-Sat preset
    await tester.tap(find.text('Mon–Sat'));
    await tester.pumpAndSettle();

    // Tap 10:00 - 19:00 time preset
    await tester.tap(find.text('10:00 – 19:00'));
    await tester.pumpAndSettle();

    // Save working hours
    await tester.tap(find.text('Save working hours'));
    await tester.pumpAndSettle();

    expect(transport.lastPutBody, isNotNull);
    final rules = transport.lastPutBody!['weeklyRules'] as List;
    expect(rules.length, 6); // Mon through Sat
    expect((rules.first as Map)['dayOfWeek'], 1);
    final interval = ((rules.first as Map)['intervals'] as List).first as Map;
    expect(interval['startMinute'], 600); // 10:00 AM
    expect(interval['endMinute'], 1140); // 07:00 PM (19:00)
  });
}
