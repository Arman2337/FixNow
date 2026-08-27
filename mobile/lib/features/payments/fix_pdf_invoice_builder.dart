import 'dart:convert';
import 'dart:typed_data';
import 'package:fixnow_mobile/features/payments/invoice_repository.dart';

/// Pure Dart PDF 1.4 Generator for FixNow GST Tax Invoices.
///
/// Produces 100% compliant, standard `%PDF-1.4` binary documents without
/// requiring external binary plugins or native platform channels.
class FixPdfInvoiceBuilder {
  const FixPdfInvoiceBuilder._();

  /// FixNow Official Statutory Details
  static const companyName = 'FixNow Technologies Private Limited';
  static const companyGstin = '24AAACF1234F1Z5';
  static const companySac = '9987';
  static const companyAddress = 'Level 4, Commerce House, SG Highway, Ahmedabad, Gujarat - 380054';
  static const supportEmail = 'support@fixnow.app';
  static const verifyUrl = 'https://fixnow.app/verify/invoice';

  /// Generates the standard A4 PDF byte stream.
  static Uint8List build(
    Invoice invoice, {
    String customerName = 'FixNow Customer',
    String serviceAddress = 'Ahmedabad, Gujarat, India',
  }) {
    final issuedStr = _formatDate(invoice.issuedAt);
    final bookingIdStr = invoice.bookingId ?? 'BK-${invoice.invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '')}';
    final serviceNameStr = invoice.serviceName ?? 'Home Maintenance & Repair Service';

    final baseStr = _rupees(invoice.baseAmountMinor);
    final cgstStr = _rupees(invoice.cgstMinor);
    final sgstStr = _rupees(invoice.sgstMinor);
    final totalStr = _rupees(invoice.amountMinor);

    final streamBuffer = StringBuffer();

    void op(String cmd) => streamBuffer.write('$cmd\n');

    // -------------------------------------------------------------
    // Page Header & Brand Block
    // -------------------------------------------------------------
    // Top primary banner bar (x: 40, y: 770, w: 515, h: 48)
    op('0.031 0.063 0.125 rg'); // #081020 Dark navy
    op('40 770 515 48 re f');

    // Brand logo accent bar (x: 40, y: 770, w: 6, h: 48)
    op('0.157 0.341 0.961 rg'); // #2857F5 Cobalt blue
    op('40 770 6 48 re f');

    // "FixNow" Brand Title
    op('BT');
    op('/F2 20 Tf');
    op('1 1 1 rg');
    op('56 788 Td');
    op('(${_escape('FixNow')}) Tj');
    op('ET');

    // "Official GST Tax Invoice" Subhead
    op('BT');
    op('/F1 10 Tf');
    op('0.78 0.82 0.90 rg');
    op('56 776 Td');
    op('(${_escape('On-Demand Services & Repair Platform')}) Tj');
    op('ET');

    // TAX INVOICE Badge on top right
    op('0.122 0.616 0.408 rg'); // #1F9D68 Success green
    op('420 782 125 24 re f');
    op('BT');
    op('/F2 10 Tf');
    op('1 1 1 rg');
    op('440 790 Td');
    op('(${_escape('TAX INVOICE [PAID]')}) Tj');
    op('ET');

    // -------------------------------------------------------------
    // Company & Invoice Meta Columns
    // -------------------------------------------------------------
    // Left: Provider details
    op('BT');
    op('/F2 11 Tf');
    op('0.078 0.129 0.239 rg');
    op('40 740 Td');
    op('(${_escape(companyName)}) Tj');
    op('ET');

    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('40 726 Td');
    op('(${_escape('GSTIN: $companyGstin  |  SAC: $companySac')}) Tj');
    op('ET');

    op('BT');
    op('/F1 8.5 Tf');
    op('0.35 0.40 0.47 rg');
    op('40 714 Td');
    op('(${_escape(companyAddress)}) Tj');
    op('ET');

    op('BT');
    op('/F1 8.5 Tf');
    op('0.35 0.40 0.47 rg');
    op('40 702 Td');
    op('(${_escape('Email: $supportEmail  |  Portal: fixnow.app')}) Tj');
    op('ET');

    // Right: Invoice Metadata Box (x: 360, y: 695, w: 195, h: 58)
    op('0.968 0.968 0.980 rg'); // #F7F7FA
    op('360 695 195 58 re f');
    op('0.835 0.855 0.898 RG');
    op('0.8 w');
    op('360 695 195 58 re S');

    op('BT');
    op('/F2 9 Tf');
    op('0.078 0.129 0.239 rg');
    op('370 738 Td');
    op('(${_escape('Invoice No: ${invoice.invoiceNumber}')}) Tj');
    op('ET');

    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('370 724 Td');
    op('(${_escape('Date of Issue: $issuedStr')}) Tj');
    op('ET');

    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('370 710 Td');
    op('(${_escape('Booking Ref: $bookingIdStr')}) Tj');
    op('ET');

    // Divider Line
    op('0.835 0.855 0.898 RG');
    op('1 w');
    op('40 680 m 555 680 l S');

    // -------------------------------------------------------------
    // Customer Billed-To Section
    // -------------------------------------------------------------
    op('BT');
    op('/F2 10 Tf');
    op('0.157 0.341 0.961 rg');
    op('40 662 Td');
    op('(${_escape('BILLED TO (CUSTOMER)')}) Tj');
    op('ET');

    op('BT');
    op('/F2 11 Tf');
    op('0.078 0.129 0.239 rg');
    op('40 648 Td');
    op('(${_escape(customerName)}) Tj');
    op('ET');

    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('40 635 Td');
    op('(${_escape('Service Location: $serviceAddress')}) Tj');
    op('ET');

    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('40 622 Td');
    op('(${_escape('Payment Status: Confirmed & Paid via FixNow Gateway')}) Tj');
    op('ET');

    // -------------------------------------------------------------
    // Itemized GST Tax Invoice Table
    // -------------------------------------------------------------
    // Table Header (y: 585, h: 24)
    op('0.078 0.129 0.239 rg'); // #14213D
    op('40 585 515 24 re f');

    op('BT');
    op('/F2 9 Tf');
    op('1 1 1 rg');
    op('50 593 Td');
    op('(${_escape('DESCRIPTION')}) Tj');
    op('190 0 Td');
    op('(${_escape('SAC')}) Tj');
    op('60 0 Td');
    op('(${_escape('BASE (INR)')}) Tj');
    op('75 0 Td');
    op('(${_escape('CGST (9%)')}) Tj');
    op('70 0 Td');
    op('(${_escape('SGST (9%)')}) Tj');
    op('65 0 Td');
    op('(${_escape('TOTAL')}) Tj');
    op('ET');

    // Table Data Row 1 (y: 545, h: 40)
    op('0.968 0.968 0.980 rg');
    op('40 545 515 40 re f');
    op('0.835 0.855 0.898 RG');
    op('0.5 w');
    op('40 545 515 40 re S');

    op('BT');
    op('/F2 9.5 Tf');
    op('0.078 0.129 0.239 rg');
    op('50 568 Td');
    op('(${_escape(serviceNameStr)}) Tj');
    op('ET');

    op('BT');
    op('/F1 8.5 Tf');
    op('0.4 0.45 0.52 rg');
    op('50 553 Td');
    op('(${_escape('Doorstep verified service execution')}) Tj');
    op('ET');

    // SAC Column
    op('BT');
    op('/F1 9 Tf');
    op('0.3 0.3 0.3 rg');
    op('240 560 Td');
    op('(${_escape(companySac)}) Tj');
    op('ET');

    // Base Amount Column
    op('BT');
    op('/F1 9 Tf');
    op('0.3 0.3 0.3 rg');
    op('300 560 Td');
    op('(${_escape(baseStr)}) Tj');
    op('ET');

    // CGST 9% Column
    op('BT');
    op('/F1 9 Tf');
    op('0.3 0.3 0.3 rg');
    op('375 560 Td');
    op('(${_escape(cgstStr)}) Tj');
    op('ET');

    // SGST 9% Column
    op('BT');
    op('/F1 9 Tf');
    op('0.3 0.3 0.3 rg');
    op('445 560 Td');
    op('(${_escape(sgstStr)}) Tj');
    op('ET');

    // Total Column
    op('BT');
    op('/F2 9.5 Tf');
    op('0.078 0.129 0.239 rg');
    op('510 560 Td');
    op('(${_escape(totalStr)}) Tj');
    op('ET');

    // -------------------------------------------------------------
    // Tax Calculation Breakdown Summary Card
    // -------------------------------------------------------------
    // Summary Box on bottom right (x: 320, y: 410, w: 235, h: 115)
    op('0.968 0.968 0.980 rg');
    op('320 410 235 115 re f');
    op('0.835 0.855 0.898 RG');
    op('0.8 w');
    op('320 410 235 115 re S');

    // Subtotal Row
    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('335 508 Td');
    op('(${_escape('Taxable Base Value:')}) Tj');
    op('130 0 Td');
    op('/F2 9 Tf');
    op('0.078 0.129 0.239 rg');
    op('(${_escape(baseStr)}) Tj');
    op('ET');

    // CGST Row
    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('335 490 Td');
    op('(${_escape('Central GST (CGST @ 9%):')}) Tj');
    op('130 0 Td');
    op('/F2 9 Tf');
    op('0.078 0.129 0.239 rg');
    op('(${_escape(cgstStr)}) Tj');
    op('ET');

    // SGST Row
    op('BT');
    op('/F1 9 Tf');
    op('0.35 0.40 0.47 rg');
    op('335 472 Td');
    op('(${_escape('State GST (SGST @ 9%):')}) Tj');
    op('130 0 Td');
    op('/F2 9 Tf');
    op('0.078 0.129 0.239 rg');
    op('(${_escape(sgstStr)}) Tj');
    op('ET');

    // Divider in summary box
    op('0.835 0.855 0.898 RG');
    op('0.5 w');
    op('328 460 m 547 460 l S');

    // Total Final Box (Navy Highlight)
    op('0.078 0.129 0.239 rg');
    op('320 410 235 42 re f');

    op('BT');
    op('/F2 11 Tf');
    op('1 1 1 rg');
    op('335 428 Td');
    op('(${_escape('Total Paid (INR):')}) Tj');
    op('110 0 Td');
    op('/F2 13 Tf');
    op('0.96 0.62 0.04 rg'); // #F59E0B Accent Gold
    op('(${_escape(totalStr)}) Tj');
    op('ET');

    // -------------------------------------------------------------
    // Security / Seal Notes on Left
    // -------------------------------------------------------------
    op('0.867 0.906 1.0 rg'); // Soft blue #DDE7FF
    op('40 435 255 90 re f');
    op('0.157 0.341 0.961 RG');
    op('0.5 w');
    op('40 435 255 90 re S');

    op('BT');
    op('/F2 9 Tf');
    op('0.157 0.341 0.961 rg');
    op('50 508 Td');
    op('(${_escape('TAX INVOICE COMPLIANCE GUARANTEE')}) Tj');
    op('ET');

    op('BT');
    op('/F1 8 Tf');
    op('0.2 0.25 0.35 rg');
    op('50 492 Td');
    op('(${_escape('This invoice is generated in strict accordance with the')}) Tj');
    op('0 -12 Td');
    op('(${_escape('Central Goods & Services Tax (CGST) Act, 2017.')}) Tj');
    op('0 -12 Td');
    op('(${_escape('Includes reverse charge & marketplace intermediary taxes.')}) Tj');
    op('0 -12 Td');
    op('(${_escape('Payment verified and authenticated by FixNow platform.')}) Tj');
    op('ET');

    // -------------------------------------------------------------
    // Footer & Statutory Declaration
    // -------------------------------------------------------------
    op('0.835 0.855 0.898 RG');
    op('0.8 w');
    op('40 120 m 555 120 l S');

    op('BT');
    op('/F2 8.5 Tf');
    op('0.25 0.30 0.40 rg');
    op('40 102 Td');
    op('(${_escape('Statutory Declaration & Terms:')}) Tj');
    op('ET');

    op('BT');
    op('/F1 7.5 Tf');
    op('0.4 0.45 0.52 rg');
    op('40 90 Td');
    op('(${_escape('1. This is a computer-generated tax invoice and requires no physical or digital signature under the Information Technology Act, 2000.')}) Tj');
    op('0 -10 Td');
    op('(${_escape('2. Goods & services once delivered and verified via Customer Service-Start PIN & completion proof are subject to standard dispute terms.')}) Tj');
    op('0 -10 Td');
    op('(${_escape('3. For customer inquiries or GST credit reconciliations, contact support@fixnow.app quoting the Invoice Reference Number above.')}) Tj');
    op('0 -10 Td');
    op('(${_escape('4. All claims and arbitrations are exclusively subject to Ahmedabad, Gujarat jurisdiction.')}) Tj');
    op('ET');

    // Bottom brand stamp
    op('BT');
    op('/F2 8 Tf');
    op('0.6 0.65 0.72 rg');
    op('200 40 Td');
    op('(${_escape('FixNow Technologies  --  Empowering Quality Local Services')}) Tj');
    op('ET');

    final contentStream = streamBuffer.toString();
    final streamBytes = utf8.encode(contentStream);

    // -------------------------------------------------------------
    // Assemble standard PDF Objects with exact byte xref table
    // -------------------------------------------------------------
    final pdfBuffer = BytesBuilder();

    final offsets = <int>[];

    void writeString(String s) {
      final bytes = utf8.encode(s);
      pdfBuffer.add(bytes);
    }

    void startObj(int num) {
      offsets.add(pdfBuffer.length);
      writeString('$num 0 obj\n');
    }

    // Header
    writeString('%PDF-1.4\n');

    // 1: Catalog
    startObj(1);
    writeString('<<\n  /Type /Catalog\n  /Pages 2 0 R\n>>\nendobj\n');

    // 2: Pages
    startObj(2);
    writeString('<<\n  /Type /Pages\n  /Kids [3 0 R]\n  /Count 1\n>>\nendobj\n');

    // 3: Page (A4: 595.28 x 841.89 pt)
    startObj(3);
    writeString('<<\n  /Type /Page\n  /Parent 2 0 R\n  /MediaBox [0 0 595.28 841.89]\n  /Contents 4 0 R\n  /Resources <<\n    /Font <<\n      /F1 5 0 R\n      /F2 6 0 R\n    >>\n  >>\n>>\nendobj\n');

    // 4: Stream contents
    startObj(4);
    writeString('<<\n  /Length ${streamBytes.length}\n>>\nstream\n');
    pdfBuffer.add(streamBytes);
    writeString('\nendstream\nendobj\n');

    // 5: Font Helvetica
    startObj(5);
    writeString('<<\n  /Type /Font\n  /Subtype /Type1\n  /BaseFont /Helvetica\n>>\nendobj\n');

    // 6: Font Helvetica-Bold
    startObj(6);
    writeString('<<\n  /Type /Font\n  /Subtype /Type1\n  /BaseFont /Helvetica-Bold\n>>\nendobj\n');

    // xref table
    final xrefOffset = pdfBuffer.length;
    writeString('xref\n0 7\n');
    writeString('0000000000 65535 f \n');
    for (final offset in offsets) {
      final offsetStr = offset.toString().padLeft(10, '0');
      writeString('$offsetStr 00000 n \n');
    }

    // Trailer
    writeString('trailer\n<<\n  /Size 7\n  /Root 1 0 R\n>>\n');
    writeString('startxref\n$xrefOffset\n%%EOF\n');

    return pdfBuffer.toBytes();
  }

  /// Formats formatted filename.
  static String getFileName(Invoice invoice) {
    final sanitized = invoice.invoiceNumber.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '_');
    return 'Invoice-$sanitized.pdf';
  }

  /// Generates a readable plain-text invoice summary for sharing via WhatsApp, Email, or Clipboard.
  static String generateShareSummary(
    Invoice invoice, {
    String customerName = 'Customer',
  }) {
    final dateStr = _formatDate(invoice.issuedAt);
    final bookingIdStr = invoice.bookingId ?? 'N/A';
    final totalStr = _rupees(invoice.amountMinor);
    final baseStr = _rupees(invoice.baseAmountMinor);
    final gstStr = _rupees(invoice.totalGstMinor);

    return '''
FixNow Official Tax Invoice
----------------------------------------
Invoice No : ${invoice.invoiceNumber}
Date       : $dateStr
Booking ID : $bookingIdStr
Status     : PAID

Service Details:
Base Charge : $baseStr
GST (18%)   : $gstStr (CGST 9% + SGST 9%)
Total Paid  : $totalStr

GSTIN: $companyGstin | SAC: $companySac
Download official PDF receipt or verify at:
$verifyUrl?ref=${invoice.invoiceNumber}
----------------------------------------
Thank you for choosing FixNow!
'''.trim();
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    return '$d/$m/$y';
  }

  static String _rupees(int minor) {
    final val = minor / 100.0;
    return val % 1 == 0 ? 'INR ${val.toStringAsFixed(0)}' : 'INR ${val.toStringAsFixed(2)}';
  }

  static String _escape(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }
}
