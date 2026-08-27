import 'dart:typed_data';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );

final dummyBytes = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0,
  0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73,
  68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0,
  0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  setUp(() {
    JobProofRepository.instance.clear();
  });

  group('JobProofRepository', () {
    test('saves and retrieves job proof accurately', () {
      final repo = JobProofRepository.instance;
      expect(repo.hasProof('booking-123'), isFalse);

      final proof = JobProof(
        bookingId: 'booking-123',
        beforePhotoBytes: dummyBytes,
        beforePhotoName: 'before.png',
        afterPhotoBytes: dummyBytes,
        afterPhotoName: 'after.png',
        notes: 'Fixed leak successfully',
        capturedAt: DateTime.now(),
      );

      repo.saveProof(proof);
      expect(repo.hasProof('booking-123'), isTrue);

      final retrieved = repo.getProof('booking-123');
      expect(retrieved, isNotNull);
      expect(retrieved!.notes, 'Fixed leak successfully');
      expect(retrieved.hasBeforePhoto, isTrue);
      expect(retrieved.hasAfterPhoto, isTrue);
      expect(retrieved.isComplete, isTrue);
    });
  });

  group('JobProofVerificationDialog', () {
    testWidgets('renders photo slots and saves captured proof', (tester) async {
      JobProof? savedProof;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  savedProof = await JobProofVerificationDialog.show(
                    context,
                    bookingId: 'test-booking-456',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Job Verification Photos'), findsOneWidget);
      expect(find.text('1. BEFORE WORK'), findsOneWidget);
      expect(find.text('2. AFTER WORK'), findsOneWidget);

      // Simulate photos
      await tester.tap(find.text('Simulate test photos'));
      await tester.pumpAndSettle();

      // Enter notes
      await tester.enterText(find.byType(TextField), 'Tested water pressure, 0 leaks');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Save Proof & Complete Job'));
      await tester.pumpAndSettle();

      expect(savedProof, isNotNull);
      expect(savedProof!.bookingId, 'test-booking-456');
      expect(savedProof!.notes, 'Tested water pressure, 0 leaks');
      expect(JobProofRepository.instance.hasProof('test-booking-456'), isTrue);
    });
  });

  group('JobProofViewerCard', () {
    testWidgets('displays before/after labels, notes, and watermark', (tester) async {
      final proof = JobProof(
        bookingId: 'view-test-789',
        beforePhotoBytes: dummyBytes,
        afterPhotoBytes: dummyBytes,
        notes: 'Tightened brass valve and tested flow.',
        capturedAt: DateTime(2026, 8, 28, 12, 30),
        proName: 'Ramesh Sharma',
      );

      await tester.pumpWidget(
        host(JobProofViewerCard(proof: proof)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verified Job Proof Photos'), findsOneWidget);
      expect(find.text('BEFORE'), findsOneWidget);
      expect(find.text('AFTER'), findsOneWidget);
      expect(find.textContaining('Tightened brass valve'), findsOneWidget);
      expect(find.textContaining('Ramesh Sharma'), findsOneWidget);
    });
  });

  group('BookingDetailScreen integration', () {
    testWidgets('shows JobProofViewerCard when proof exists for the booking',
        (tester) async {
      final booking = CustomerBooking(
        id: 'booking-proof-detail-1',
        serviceCategoryId: 'plumbing',
        status: 'COMPLETED',
        description: 'Fix bathroom tap leak',
        createdAt: DateTime.now(),
        version: 1,
        locationLatitude: 28.5,
        locationLongitude: 77.2,
      );

      // Save proof into repository
      JobProofRepository.instance.saveProof(
        JobProof(
          bookingId: booking.id,
          beforePhotoBytes: dummyBytes,
          afterPhotoBytes: dummyBytes,
          notes: 'Replaced ceramic cartridge',
          capturedAt: DateTime.now(),
        ),
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: BookingDetailScreen(booking: booking),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Verified Job Proof Photos'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Replaced ceramic cartridge'),
        findsOneWidget,
      );
    });
  });
}
