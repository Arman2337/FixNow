import 'dart:async';
import 'dart:io';

import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  test(
    'HTTP refresh cannot erase a live point received during the request',
    () async {
      final source = _Source(
        _tracking(sequence: 5, availability: LocationAvailability.unavailable),
      );
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: source,
      );
      addTearDown(controller.dispose);
      await controller.loadSnapshot();
      final pending = Completer<BookingTracking>();
      source.pending = pending;
      final refresh = controller.loadSnapshot();
      final point = ProviderMapLocation(
        latitude: 22.89,
        longitude: 72.99,
        accuracyMeters: 10,
        capturedAt: DateTime.now(),
        receivedAt: DateTime.now(),
      );
      await controller.applyRealtime(_tracking(sequence: 5, provider: point));
      pending.complete(
        _tracking(sequence: 5, availability: LocationAvailability.unavailable),
      );
      await refresh;
      expect(controller.tracking?.providerLocation, same(point));
      expect(
        controller.tracking?.locationAvailability,
        LocationAvailability.live,
      );
    },
  );

  test(
    'ignores stale events and reconciles a sequence gap from snapshot',
    () async {
      final source = _Source(_tracking(sequence: 5));
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: source,
      );
      await controller.loadSnapshot();
      await controller.applyRealtime(_tracking(sequence: 4));
      expect(controller.tracking?.sequence, 5);
      source.value = _tracking(sequence: 8);
      await controller.applyRealtime(_tracking(sequence: 7));
      expect(controller.tracking?.sequence, 8);
      expect(source.calls, 2);
    },
  );

  test('accepts location updates that reuse the current sequence', () async {
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(
        _tracking(sequence: 5, availability: LocationAvailability.unavailable),
      ),
    );
    await controller.loadSnapshot();

    // Simulate a realtime location update that does not bump the booking sequence.
    await controller.applyRealtime(
      _tracking(sequence: 5, availability: LocationAvailability.live),
    );

    expect(
      controller.tracking?.locationAvailability,
      LocationAvailability.live,
    );
  });

  test(
    'a failed snapshot reconcile still lands the newer live projection',
    () async {
      final source = _Source(
        _tracking(sequence: 1, availability: LocationAvailability.unavailable),
      );
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: source,
      );
      addTearDown(controller.dispose);
      await controller.loadSnapshot();

      // The booking jumps versions while the snapshot backend is unreachable;
      // the reconcile fetch fails but the live projection in hand is newer.
      source.error = const FormatException('backend restarting');
      final provider = ProviderMapLocation(
        latitude: 22.9,
        longitude: 72.98,
        accuracyMeters: 10,
        capturedAt: DateTime.now(),
        receivedAt: DateTime.now(),
      );
      await controller.applyRealtime(
        _tracking(sequence: 3, provider: provider),
      );

      expect(controller.tracking?.sequence, 3);
      expect(controller.tracking?.providerLocation, same(provider));
      expect(controller.connection, TrackingConnection.live);
      expect(controller.message, isNull);
    },
  );

  test('marks a frozen live point stale and keeps the last pin', () async {
    final frozen = ProviderMapLocation(
      latitude: 22.9,
      longitude: 72.98,
      accuracyMeters: 10,
      capturedAt: DateTime.now().subtract(const Duration(seconds: 70)),
      receivedAt: DateTime.now().subtract(const Duration(seconds: 70)),
    );
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(_tracking(sequence: 1, provider: frozen)),
    );
    addTearDown(controller.dispose);
    await controller.loadSnapshot();

    controller.evaluateStaleness();

    expect(
      controller.tracking?.locationAvailability,
      LocationAvailability.stale,
    );
    expect(controller.tracking?.providerLocation, same(frozen));
  });

  test('a fresh projection restores live after staleness', () async {
    final frozen = ProviderMapLocation(
      latitude: 22.9,
      longitude: 72.98,
      accuracyMeters: 10,
      capturedAt: DateTime.now().subtract(const Duration(seconds: 70)),
      receivedAt: DateTime.now().subtract(const Duration(seconds: 70)),
    );
    final source = _Source(_tracking(sequence: 1, provider: frozen));
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: source,
    );
    addTearDown(controller.dispose);
    await controller.loadSnapshot();
    controller.evaluateStaleness();
    expect(
      controller.tracking?.locationAvailability,
      LocationAvailability.stale,
    );

    await controller.applyRealtime(
      _tracking(
        sequence: 1,
        provider: ProviderMapLocation(
          latitude: 22.91,
          longitude: 72.99,
          accuracyMeters: 10,
          capturedAt: DateTime.now(),
          receivedAt: DateTime.now(),
        ),
      ),
    );

    expect(
      controller.tracking?.locationAvailability,
      LocationAvailability.live,
    );
  });

  testWidgets(
    'copies the service-start OTP only after the clipboard succeeds',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: _Source(
          _tracking(sequence: 1, status: 'EN_ROUTE', serviceStartOtp: '4821'),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BookingTrackingScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Copy service-start OTP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(copied, '4821');
      expect(find.text('OTP copied to clipboard'), findsOneWidget);
      controller.dispose();
    },
  );

  test(
    'fetches the service-start OTP when a projection goes en route',
    () async {
      final source = _Source(_tracking(sequence: 1, status: 'ACCEPTED'));
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: source,
      );
      await controller.loadSnapshot();
      expect(controller.tracking?.serviceStartOtp, isNull);

      source.otp = '4821';
      await controller.applyRealtime(
        _tracking(sequence: 2, status: 'EN_ROUTE'),
      );

      expect(controller.tracking?.serviceStartOtp, '4821');
      expect(source.otpCalls, 1);
    },
  );

  test(
    'keeps a newer live projection after reconciling a sequence gap',
    () async {
      final source = _Source(
        _tracking(sequence: 1, availability: LocationAvailability.unavailable),
      );
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: source,
      );
      await controller.loadSnapshot();

      final provider = ProviderMapLocation(
        latitude: 22.8982,
        longitude: 72.9928,
        accuracyMeters: 15,
        capturedAt: DateTime(2026, 8, 21, 11, 31),
        receivedAt: DateTime(2026, 8, 21, 11, 34),
      );
      source.value = _tracking(
        sequence: 2,
        availability: LocationAvailability.unavailable,
      );

      await controller.applyRealtime(
        _tracking(sequence: 3, provider: provider),
      );

      expect(controller.tracking?.sequence, 3);
      expect(
        controller.tracking?.locationAvailability,
        LocationAvailability.live,
      );
      expect(controller.tracking?.providerLocation, provider);
      expect(source.calls, 2);
    },
  );

  test('preserves last status and reports offline on disconnect', () async {
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(_tracking(sequence: 1)),
    );
    await controller.loadSnapshot();
    controller.markDisconnected();
    expect(controller.connection, TrackingConnection.offline);
    expect(controller.tracking?.sequence, 1);
  });

  testWidgets('shows honest ETA, unavailable location, and retry fallback', (
    tester,
  ) async {
    final source = _Source(
      _tracking(
        sequence: 1,
        availability: LocationAvailability.unavailable,
        eta: null,
      ),
    );
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: source,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingTrackingScreen(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Provider is on the way'), findsOneWidget);
    expect(find.text('Live location unavailable'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    controller.markDisconnected();
    await tester.pump();
    expect(find.text('Updates paused'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('labels both ends of a live provider journey', (tester) async {
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(
        _tracking(
          sequence: 1,
          provider: ProviderMapLocation(
            latitude: 22.89,
            longitude: 72.99,
            accuracyMeters: 10,
            capturedAt: DateTime(2026),
            receivedAt: DateTime(2026),
          ),
          customer: const CustomerMapLocation(
            latitude: 23.02,
            longitude: 73.07,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingTrackingScreen(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Live location available'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('does not offer customer cancellation after provider departure', (
    tester,
  ) async {
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(_tracking(sequence: 1, status: 'EN_ROUTE')),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingTrackingScreen(
          controller: controller,
          onCancel: (_) async => throw UnimplementedError(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cancel Booking'), findsNothing);
    controller.dispose();
  });

  testWidgets(
    'does not invent provider trust data when tracking data is missing',
    (tester) async {
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: _Source(
          _tracking(
            sequence: 1,
            availability: LocationAvailability.unavailable,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BookingTrackingScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rating unavailable'), findsOneWidget);
      expect(find.text('Job history unavailable'), findsOneWidget);
      expect(find.text('Aadhaar & Trade Verified'), findsNothing);
      controller.dispose();
    },
  );
  testWidgets(
    'hides transit journey map and shows on-site status when work has started',
    (tester) async {
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: _Source(_tracking(sequence: 2, status: 'IN_PROGRESS')),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BookingTrackingScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Service in progress'), findsOneWidget);
      expect(find.text('Work started'), findsOneWidget);
      expect(find.text('Technician is working on-site'), findsOneWidget);
      // Transit map and provider journey are removed
      expect(find.text('Provider journey'), findsNothing);
      expect(find.text('Estimated arrival'), findsNothing);
    },
  );

  // Regression: the Service Summary card was entirely `const`, so it rendered
  // "₹449" with invented "Standard Inspection & Diagnosis ₹299" and
  // "Emergency Dispatch Convenience Fee ₹150" rows for every booking, whatever
  // the provider had actually charged. The same booking showed the correct
  // real total on the detail screen.
  testWidgets(
    'service summary shows the real itemised total, not a fixed Rs449',
    (tester) async {
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: _Source(
          _tracking(
            sequence: 3,
            status: 'IN_PROGRESS',
            items: const [
              BookingLineItem(
                id: 'a',
                name: 'Tap & Mixer Repair',
                quantity: 1,
                unitPriceMinor: 14900,
              ),
              BookingLineItem(
                id: 'b',
                name: 'Flush Tank & Jet Spray Fix',
                quantity: 1,
                unitPriceMinor: 24900,
              ),
              BookingLineItem(
                id: 'c',
                name: 'leakage tap',
                quantity: 1,
                unitPriceMinor: 10000,
              ),
            ],
            // 49800 subtotal + 8964 GST = 58764, matching the provider's sheet.
            pricing: const BookingPricing(
              subtotalMinor: 49800,
              gstMinor: 8964,
              totalMinor: 58764,
              currency: 'INR',
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BookingTrackingScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('₹587.64'), findsOneWidget);
      expect(find.text('Tap & Mixer Repair'), findsOneWidget);
      expect(find.text('Flush Tank & Jet Spray Fix'), findsOneWidget);
      expect(find.text('leakage tap'), findsOneWidget);
      expect(find.text('GST (18%)'), findsOneWidget);
      expect(find.text('₹89.64'), findsOneWidget);

      // The fabricated breakdown must be gone entirely.
      expect(find.text('₹449'), findsNothing);
      expect(find.text('Standard Inspection & Diagnosis'), findsNothing);
      expect(find.text('Emergency Dispatch Convenience Fee'), findsNothing);
      expect(find.text('₹299'), findsNothing);
      expect(find.text('₹150'), findsNothing);

      controller.dispose();
    },
  );

  testWidgets(
    'service summary states when a booking has no itemised services',
    (tester) async {
      final controller = BookingTrackingController(
        bookingId: 'booking-1',
        source: _Source(_tracking(sequence: 1)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BookingTrackingScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('No itemised services'), findsOneWidget);
      expect(find.text('₹449'), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('service summary reflects a live on-site price adjustment', (
    tester,
  ) async {
    final source = _Source(_tracking(sequence: 1, status: 'IN_PROGRESS'));
    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: source,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BookingTrackingScreen(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('No itemised services'), findsOneWidget);

    // The provider raises the line: the projection carries the new items and
    // the recomputed total on one frame.
    await controller.applyRealtime(
      _tracking(
        sequence: 2,
        status: 'IN_PROGRESS',
        items: const [
          BookingLineItem(
            id: 'a',
            name: 'Tap & Mixer Repair',
            quantity: 1,
            unitPriceMinor: 24900,
          ),
        ],
        pricing: const BookingPricing(
          subtotalMinor: 24900,
          gstMinor: 4482,
          totalMinor: 29382,
          currency: 'INR',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('₹293.82'), findsOneWidget);
    expect(find.text('Tap & Mixer Repair'), findsOneWidget);
    expect(find.textContaining('No itemised services'), findsNothing);

    controller.dispose();
  });

  testWidgets('keeps tracking header within narrow large-text bounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = BookingTrackingController(
      bookingId: 'booking-1',
      source: _Source(_tracking(sequence: 1)),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: BookingTrackingScreen(controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    controller.dispose();
  });
}

BookingTracking _tracking({
  required int sequence,
  String status = 'EN_ROUTE',
  LocationAvailability availability = LocationAvailability.live,
  int? eta = 12,
  ProviderMapLocation? provider,
  CustomerMapLocation? customer,
  String? serviceStartOtp,
  List<BookingLineItem> items = const [],
  BookingPricing? pricing,
}) => BookingTracking(
  bookingId: 'booking-1',
  status: status,
  sequence: sequence,
  locationAvailability: availability,
  estimatedMinutes: eta,
  providerLocation: provider,
  customerLocation: customer,
  serviceStartOtp: serviceStartOtp,
  items: items,
  pricing: pricing,
);

class _Source implements BookingTrackingSource {
  _Source(this.value);
  BookingTracking value;
  int calls = 0;
  Completer<BookingTracking>? pending;
  Object? error;
  String? otp;
  int otpCalls = 0;
  @override
  Future<BookingTracking> fetchSnapshot(String bookingId) async {
    calls += 1;
    if (error != null) throw error!;
    return pending == null ? value : await pending!.future;
  }

  @override
  Future<String?> fetchServiceStartOtp(String bookingId) async {
    otpCalls += 1;
    return otp;
  }
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpRequest();

  @override
  void close({bool force = false}) {}
}

class _FakeHttpRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpResponse();
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final List<int> _kTransparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
