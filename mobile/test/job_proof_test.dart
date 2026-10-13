import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/fix_job_proof_panel.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_idle.dart';
import 'support/accessibility_harness.dart';

const _beforeId = 'photo-before';
const _afterId = 'photo-after';

Map<String, Object?> _photo(String id, JobProofStage stage) => {
  'id': id,
  'bookingId': 'booking-1',
  'stage': stage.wireValue,
  'contentType': 'image/jpeg',
  'sizeBytes': 6,
  'createdAt': '2026-10-08T09:30:00.000Z',
};

class ScriptedApi implements ApiTransport {
  ScriptedApi(this.answers);

  final List<Object> answers;
  int calls = 0;
  ApiException? lastFailure;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    calls += 1;
    final answer = calls <= answers.length ? answers[calls - 1] : answers.last;
    if (answer is ApiException) {
      lastFailure = answer;
      throw answer;
    }
    return ApiResponse(statusCode: 200, body: answer);
  }
}

class ScriptedDownloader implements BinaryDownloader {
  ScriptedDownloader(this.answers);

  final Map<String, Object> answers;
  final List<String> requested = [];

  @override
  Future<Uint8List> downloadFile({
    required String path,
    required String bearerToken,
    int maxBytes = 1 << 24,
  }) async {
    requested.add(path);
    // The path ends `.../photos/<photoId>/content`, so the photo id is the
    // second-to-last segment.
    final segments = path.split('/');
    final answer = answers[segments[segments.length - 2]];
    if (answer is ApiException) throw answer;
    return Uint8List.fromList(answer! as List<int>);
  }
}

const _offline = ApiException(ApiFailureKind.offline, 'No network connection.');

/// A real 1×1 PNG. `Image.memory` genuinely decodes, so feeding it arbitrary
/// bytes would fail on image data rather than on the behaviour under test.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

JobProofController _controller(
  ApiTransport api, [
  BinaryDownloader? downloader,
]) => JobProofController(
  BookingRepository(api: api, accessToken: () async => 'token'),
  downloader: downloader,
);

BookingRepository _repository(ApiTransport api) =>
    BookingRepository(api: api, accessToken: () async => 'token');

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  group('job proof repository', () {
    test('reads the {photos: [...]} envelope the backend actually returns', () async {
      final photos = await _repository(
        ScriptedApi([
          {
            'photos': [
              _photo(_beforeId, JobProofStage.before),
              _photo(_afterId, JobProofStage.after),
            ],
          },
        ]),
      ).jobProofPhotos('booking-1');

      expect(photos.map((photo) => photo.stage), [
        JobProofStage.before,
        JobProofStage.after,
      ]);
      expect(photos.first.bookingId, 'booking-1');
    });

    test('rejects a bare list rather than silently returning nothing', () async {
      // FN-110's review-photo read parses a bare list, which is why it always
      // returns empty against the live API. Recorded as FN-144. This asserts we
      // did not repeat the mistake here.
      await expectLater(
        _repository(
          ScriptedApi([
            [_photo(_beforeId, JobProofStage.before)],
          ]),
        ).jobProofPhotos('booking-1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('rejects a photo whose stage is not one we know', () async {
      await expectLater(
        _repository(
          ScriptedApi([
            {
              'photos': [
                {'id': 'x', 'bookingId': 'booking-1', 'stage': 'DURING'},
              ],
            },
          ]),
        ).jobProofPhotos('booking-1'),
        throwsA(isA<ApiException>()),
      );
    });

    test('fetches bytes from the content endpoint, never a URL', () async {
      final downloader = ScriptedDownloader({
        _beforeId: <int>[1, 2, 3],
      });
      final bytes = await _repository(
        ScriptedApi([
          {
            'photos': [_photo(_beforeId, JobProofStage.before)],
          },
        ]),
      ).jobProofBytes('booking-1', _beforeId, downloader);

      expect(bytes, Uint8List.fromList([1, 2, 3]));
      expect(
        downloader.requested.single,
        'bookings/booking-1/job-proof/photos/photo-before/content',
      );
    });
  });

  group('JobProofController', () {
    final bothPhotos = {
      'photos': [
        _photo(_beforeId, JobProofStage.before),
        _photo(_afterId, JobProofStage.after),
      ],
    };

    test('reports "none" when the provider captured nothing', () async {
      final controller = _controller(
        ScriptedApi([
          {
            'photos': <Object?>[],
          },
        ]),
        ScriptedDownloader(const {}),
      );

      await controller.load('booking-1');

      expect(controller.status, JobProofStatus.none);
      expect(controller.hasBefore, isFalse);
      expect(controller.hasAfter, isFalse);
    });

    test('reports "ready" with both sides fetched', () async {
      final controller = _controller(
        ScriptedApi([bothPhotos]),
        ScriptedDownloader({
          'photo-before': _png,
          'photo-after': _png,
        }),
      );

      await controller.load('booking-1');

      expect(controller.status, JobProofStatus.ready);
      expect(controller.hasBefore, isTrue);
      expect(controller.hasAfter, isTrue);
      expect(controller.beforeCapturedAt, isNotNull);
    });

    test('names the missing side rather than showing an empty half', () async {
      final controller = _controller(
        ScriptedApi([
          {
            'photos': [_photo(_beforeId, JobProofStage.before)],
          },
        ]),
        ScriptedDownloader({'photo-before': _png}),
      );

      await controller.load('booking-1');

      expect(controller.status, JobProofStatus.partial);
      expect(controller.missingSideLabel, 'after');
    });

    test('keeps the side that loaded when the other cannot be fetched', () async {
      final controller = _controller(
        ScriptedApi([bothPhotos]),
        ScriptedDownloader({
          'photo-before': _png,
          'photo-after': _offline,
        }),
      );

      await controller.load('booking-1');

      expect(controller.hasBefore, isTrue);
      expect(controller.hasAfter, isFalse);
      expect(controller.status, JobProofStatus.partial);
      expect(controller.missingSideLabel, 'after');
    });

    test('a failed read is an error, never "no photos"', () async {
      final controller = _controller(ScriptedApi([_offline]));

      await controller.load('booking-1');

      // Conflating these would tell a customer their pro took no photos when
      // the truth is that we could not ask.
      expect(controller.status, JobProofStatus.error);
      expect(controller.message, contains('Check your connection'));
    });

    test('says photos are unavailable when the transport cannot fetch bytes', () async {
      final controller = _controller(
        ScriptedApi([bothPhotos]),
        // No downloader wired: the honest outcome is "cannot show", not an
        // empty frame that looks like a missing photo.
      );

      await controller.load('booking-1');

      expect(controller.status, JobProofStatus.partial);
      expect(controller.hasBefore, isFalse);
      expect(controller.hasAfter, isFalse);
    });

    test('a failed upload returns a safe message, never a raw error', () async {
      final controller = _controller(ScriptedApi([_offline]));

      final failure = await controller.capture(
        id: 'booking-1',
        stage: JobProofStage.before,
        bytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
      );

      expect(failure, isNotNull);
      expect(failure, isNot(contains('ApiException')));
    });
  });

  group('FixJobProofPanel', () {
    testWidgets('renders nothing when the provider captured nothing', (
      tester,
    ) async {
      final controller = _controller(
        ScriptedApi([
          {
            'photos': <Object?>[],
          },
        ]),
      );
      await controller.load('booking-1');

      await tester.pumpWidget(
        _wrap(
          FixJobProofPanel(controller: controller, bookingId: 'booking-1'),
        ),
      );
      await tester.pump();

      expect(find.byType(FixJobProofPanel), findsOneWidget);
      expect(find.text('Work photos'), findsNothing);
    });

    testWidgets('says which side is missing when the pair is incomplete', (
      tester,
    ) async {
      final controller = _controller(
        ScriptedApi([
          {
            'photos': [_photo(_beforeId, JobProofStage.before)],
          },
        ]),
        ScriptedDownloader({'photo-before': _png}),
      );
      await controller.load('booking-1');

      await tester.pumpWidget(
        _wrap(
          FixJobProofPanel(controller: controller, bookingId: 'booking-1'),
        ),
      );
      await tester.pump();

      expect(find.text('Work photos'), findsOneWidget);
      expect(
        find.textContaining('The after photo has not been uploaded'),
        findsOneWidget,
      );
    });

    testWidgets('offers a retry when the load failed', (tester) async {
      final controller = _controller(
        ScriptedApi([_offline, {'photos': <Object?>[]}]),
      );
      await controller.load('booking-1');

      await tester.pumpWidget(
        _wrap(
          FixJobProofPanel(controller: controller, bookingId: 'booking-1'),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Job photos could not be loaded'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpIdle();
      // Retried, and the failure is now honest about there being nothing.
      expect(find.text('Work photos'), findsNothing);
    });

    testWidgets('the slider is described for a screen-reader user', (
      tester,
    ) async {
      final controller = _controller(
        ScriptedApi([
          {
            'photos': [
              _photo(_beforeId, JobProofStage.before),
              _photo(_afterId, JobProofStage.after),
            ],
          },
        ]),
        ScriptedDownloader({
          'photo-before': _png,
          'photo-after': _png,
        }),
      );
      await controller.load('booking-1');

      await tester.pumpForAccessibility(
        _wrap(
          FixJobProofPanel(controller: controller, bookingId: 'booking-1'),
        ),
        viewport: const Size(400, 800),
      );

      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((node) => node.properties.label)
          .whereType<String>()
          .join(' | ');
      expect(labels, contains('Before and after photos of the completed work'));

      await tester.expectActionsAreLabelled(screen: 'the job proof panel');
    });

    testWidgets('the panel survives 200% text and 48px targets', (tester) async {
      final controller = _controller(
        ScriptedApi([
          {
            'photos': [_photo(_beforeId, JobProofStage.before)],
          },
        ]),
        ScriptedDownloader({'photo-before': _png}),
      );
      await controller.load('booking-1');

      await tester.pumpForAccessibility(
        _wrap(
          FixJobProofPanel(controller: controller, bookingId: 'booking-1'),
        ),
        viewport: const Size(400, 900),
      );
      tester.expectRendersWithoutOverflow(component: 'FixJobProofPanel');
      await tester.expectMinimumTouchTargets(screen: 'FixJobProofPanel');
    });
  });

  group('JobProofVerificationDialog', () {
    testWidgets('a failed upload keeps the dialog open and says so', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => JobProofVerificationDialog.show(
                context,
                bookingId: 'booking-1',
                onUpload: (stage, bytes) async =>
                    'The photo was not uploaded.',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpIdle();

      // Simulate the pro supplying both photos, then submitting.
      await tester.tap(find.text('Simulate test photos'));
      await tester.pumpIdle();
      await tester.tap(find.text('Save Proof & Complete Job'));
      await tester.pumpIdle();

      expect(
        find.textContaining('The photo was not uploaded.'),
        findsOneWidget,
      );
      // The sheet is still open: a pro who believes a photo was saved when it
      // was not will not retake it.
      expect(find.text('Save Proof & Complete Job'), findsOneWidget);
    });

    testWidgets('a successful upload closes the dialog', (tester) async {
      final uploaded = <JobProofStage>[];
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => JobProofVerificationDialog.show(
                context,
                bookingId: 'booking-1',
                onUpload: (stage, bytes) async {
                  uploaded.add(stage);
                  return null;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpIdle();
      await tester.tap(find.text('Simulate test photos'));
      await tester.pumpIdle();
      await tester.tap(find.text('Save Proof & Complete Job'));
      await tester.pumpIdle();

      expect(uploaded, [
        JobProofStage.before,
        JobProofStage.after,
      ]);
      expect(find.text('Save Proof & Complete Job'), findsNothing);
    });
  });
}