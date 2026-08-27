import 'dart:convert';
import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/payments/fix_pdf_invoice_builder.dart';
import 'package:fixnow_mobile/features/payments/fix_share_invoice_sheet.dart';
import 'package:fixnow_mobile/features/payments/invoice_repository.dart';
import 'package:fixnow_mobile/features/payments/invoice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_idle.dart';

class _FakeTransport implements ApiTransport {
  _FakeTransport(this.respond);

  final ApiResponse Function(ApiRequest request) respond;

  @override
  Future<ApiResponse> send(ApiRequest request) async => respond(request);
}

void main() {
  final sampleInvoice = Invoice(
    invoiceNumber: 'INV-2026-0899',
    issuedAt: DateTime(2026, 8, 28, 14, 30),
    amountLabel: '₹499',
    statusLabel: 'PAID',
    amountMinor: 49900,
    currency: 'INR',
    bookingId: 'booking-seed-1',
    serviceName: 'AC Deep Service & Jet Clean',
  );

  group('FixPdfInvoiceBuilder', () {
    test('calculates accurate 18% inclusive GST breakdown', () {
      // For ₹499 (49900 paise):
      // Base = (49900 / 1.18).round() = 42288 paise (₹422.88)
      // Total GST = 49900 - 42288 = 7612 paise (₹76.12)
      // CGST 9% = 3806 paise (₹38.06)
      // SGST 9% = 3806 paise (₹38.06)
      expect(sampleInvoice.baseAmountMinor, 42288);
      expect(sampleInvoice.cgstMinor, 3806);
      expect(sampleInvoice.sgstMinor, 3806);
      expect(sampleInvoice.totalGstMinor, 7612);

      // Sum of Base + CGST + SGST must strictly equal total amountMinor
      expect(
        sampleInvoice.baseAmountMinor + sampleInvoice.cgstMinor + sampleInvoice.sgstMinor,
        sampleInvoice.amountMinor,
      );

      expect(sampleInvoice.baseAmountLabel, '₹422.88');
      expect(sampleInvoice.cgstLabel, '₹38.06');
      expect(sampleInvoice.sgstLabel, '₹38.06');
      expect(sampleInvoice.totalGstLabel, '₹76.12');
    });

    test('generates compliant %PDF-1.4 binary stream with valid xref and EOF', () {
      final pdfBytes = FixPdfInvoiceBuilder.build(
        sampleInvoice,
        customerName: 'Rahul Verma',
        serviceAddress: 'Vastrapur, Ahmedabad, Gujarat',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final pdfString = utf8.decode(pdfBytes, allowMalformed: true);

      // Verify standard PDF header and termination
      expect(pdfString.startsWith('%PDF-1.4'), isTrue);
      expect(pdfString.contains('startxref'), isTrue);
      expect(pdfString.contains('%%EOF'), isTrue);

      // Verify FixNow statutory details are embedded in stream
      expect(pdfString.contains('FixNow'), isTrue);
      expect(pdfString.contains('24AAACF1234F1Z5'), isTrue); // GSTIN
      expect(pdfString.contains('9987'), isTrue); // SAC Code
      expect(pdfString.contains('INV-2026-0899'), isTrue);
      expect(pdfString.contains('Rahul Verma'), isTrue);
      expect(pdfString.contains('TAX INVOICE'), isTrue);
    });

    test('generates standardized filename and plain-text share summary', () {
      final fileName = FixPdfInvoiceBuilder.getFileName(sampleInvoice);
      expect(fileName, 'Invoice-INV-2026-0899.pdf');

      final summary = FixPdfInvoiceBuilder.generateShareSummary(sampleInvoice);
      expect(summary.contains('INV-2026-0899'), isTrue);
      expect(summary.contains('PAID'), isTrue);
      expect(summary.contains('GSTIN: 24AAACF1234F1Z5'), isTrue);
      expect(summary.contains('SAC: 9987'), isTrue);
      expect(summary.contains('booking-seed-1'), isTrue);
    });
  });

  group('FixShareInvoiceSheet', () {
    testWidgets('renders all share actions and handles copy/save callbacks', (tester) async {
      bool saveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FixShareInvoiceSheet.show(
                  context,
                  invoice: sampleInvoice,
                  onSavePdf: () async {
                    saveCalled = true;
                    return '/storage/emulated/0/Download/Invoice.pdf';
                  },
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open share sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet contents
      expect(find.text('INV-2026-0899'), findsOneWidget);
      expect(find.text('GST PAID'), findsOneWidget);
      expect(find.text('Share or Export Invoice'), findsOneWidget);
      expect(find.text('Share via WhatsApp'), findsOneWidget);
      expect(find.text('Share via Email'), findsOneWidget);
      expect(find.text('Copy Invoice Summary & Verification Link'), findsOneWidget);
      expect(find.text('Save PDF to Device Storage'), findsOneWidget);

      // Tap Save to device storage
      await tester.tap(find.text('Save PDF to Device Storage'));
      await tester.pumpAndSettle();

      expect(saveCalled, isTrue);
      expect(find.textContaining('Saved'), findsOneWidget);
    });
  });

  group('InvoiceScreen PDF and Tax integration', () {
    testWidgets('renders GST tax breakdown and triggers download and share actions', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final transport = _FakeTransport((request) {
        if (request.path == 'payments/orders/booking/bk-101') {
          return ApiResponse(
            statusCode: 200,
            body: {
              'id': 'order-101',
              'bookingId': 'bk-101',
              'amountMinor': 49900,
              'currency': 'INR',
              'status': 'PAID',
            },
          );
        }
        return ApiResponse(
          statusCode: 200,
          body: {
            'invoiceNumber': 'INV-2026-0101',
            'issuedAt': '2026-08-28T10:00:00.000Z',
            'amountMinor': 49900,
            'currency': 'INR',
            'status': 'PAID',
          },
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: InvoiceScreen(
            repository: InvoiceRepository(transport),
            bookingId: 'bk-101',
          ),
        ),
      );
      await tester.pumpIdle();

      // Invoice header & amount
      expect(find.text('INV-2026-0101'), findsNWidgets(2));
      expect(find.text('₹499'), findsOneWidget);

      // GST Tax Breakdown card
      expect(find.text('GST Tax Breakdown'), findsOneWidget);
      expect(find.text('SAC 9987 • 18% GST'), findsOneWidget);
      expect(find.text('Taxable Service Base'), findsOneWidget);
      expect(find.text('Central GST (CGST @ 9%)'), findsOneWidget);
      expect(find.text('State GST (SGST @ 9%)'), findsOneWidget);
      expect(find.text('Total GST (18%)'), findsOneWidget);

      // Action buttons
      expect(find.text('Download PDF Invoice'), findsOneWidget);
      expect(find.text('Share Invoice'), findsOneWidget);

      // Tap Download PDF Invoice
      await tester.tap(find.text('Download PDF Invoice'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Downloaded Invoice-INV-2026-0101.pdf'), findsOneWidget);

      // Tap Share Invoice opens bottom sheet
      await tester.tap(find.text('Share Invoice'));
      await tester.pumpAndSettle();

      expect(find.text('Share or Export Invoice'), findsOneWidget);
      expect(find.text('Share via WhatsApp'), findsOneWidget);
    });
  });
}
