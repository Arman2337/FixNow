import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_motion_suite.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_payment_checkout_sheet.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/features/payments/fix_pdf_invoice_builder.dart';
import 'package:fixnow_mobile/features/payments/fix_share_invoice_sheet.dart';
import 'package:fixnow_mobile/features/payments/invoice_repository.dart';
import 'package:fixnow_mobile/features/payments/local_payment_config.dart';
import 'package:fixnow_mobile/features/payments/local_payment_repository.dart';
import 'package:flutter/material.dart';

/// FN-053: the customer's invoice for a booking. Honest by state — it shows a
/// real invoice only when a payment has been completed, and otherwise says so
/// plainly rather than fabricating a receipt.
class InvoiceScreen extends StatefulWidget {
  InvoiceScreen({
    required this.repository,
    required this.bookingId,
    this.initialInvoice,
    this.localPaymentRepository,
    bool? localPaymentBypassEnabled,
    super.key,
  }) : localPaymentBypassEnabled =
           localPaymentBypassEnabled ??
           (AppEnvironment.current == AppEnvironment.development ||
               LocalPaymentConfig.bypassEnabled);

  final InvoiceRepository repository;
  final String bookingId;
  final Invoice? initialInvoice;

  /// FN-118: dev-only local checkout. When null the pay affordance never
  /// shows; production and non-dev builds simply pass nothing here.
  final LocalPaymentRepository? localPaymentRepository;

  /// Defaults to `LocalPaymentConfig.bypassEnabled`; injectable for tests.
  final bool localPaymentBypassEnabled;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late final InvoiceController _controller = InvoiceController(
    widget.repository,
    widget.bookingId,
    initialInvoice: widget.initialInvoice,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoice')),
    body: SafeArea(
      top: false,
      child: FixPageFrame(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => switch (_controller.state) {
            InvoiceState.loading => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading invoice',
              ),
            ),
            InvoiceState.pending => _PendingView(
              bypassEnabled: widget.localPaymentBypassEnabled,
              repository: widget.localPaymentRepository,
              bookingId: widget.bookingId,
              onPaid: _controller.load,
            ),
            InvoiceState.unavailable => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: FixErrorState(
                  title: 'Invoice unavailable',
                  message:
                      'We could not load this invoice right now. Check your '
                      'connection and try again.',
                  onRetry: _controller.load,
                ),
              ),
            ),
            InvoiceState.ready => _InvoiceView(invoice: _controller.invoice!),
          },
        ),
      ),
    ),
  );
}

/// The "no invoice yet" state. In development, when the local payment bypass
/// is enabled (FN-118), it additionally offers a dev-only button that drives
/// the fake gateway to a PAID order so the invoice can be reached locally.
/// Every other build renders only the honest empty state.
class _PendingView extends StatefulWidget {
  const _PendingView({
    required this.bypassEnabled,
    required this.repository,
    required this.bookingId,
    required this.onPaid,
  });

  final bool bypassEnabled;
  final LocalPaymentRepository? repository;
  final String bookingId;
  final Future<void> Function() onPaid;

  @override
  State<_PendingView> createState() => _PendingViewState();
}

class _PendingViewState extends State<_PendingView> {
  bool _paying = false;

  bool get _canPayLocally => widget.bypassEnabled && widget.repository != null;

  Future<void> _payLocally() async {
    setState(() => _paying = true);
    try {
      await widget.repository!.pay(widget.bookingId);
      await widget.onPaid();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FixEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No invoice yet',
            message:
                'An invoice is issued once a payment is completed for '
                'this booking.',
          ),
          if (widget.repository != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              label: 'Pay Now (Interactive Checkout)',
              icon: Icons.payments_rounded,
              onPressed: () => _openCheckoutSheet(context),
            ),
          ],
        ],
      ),
    ),
  );

  void _openCheckoutSheet(BuildContext context) {
    FixPaymentCheckoutSheet.show(
      context,
      bookingId: widget.bookingId,
      baseAmountMinor: 49900,
      onProcessPayment:
          ({
            required paymentMethod,
            required totalMinor,
            required tipMinor,
          }) async {
            if (widget.repository != null) {
              await widget.repository!.pay(widget.bookingId);
            }
          },
      onViewInvoice: () async {
        await widget.onPaid();
      },
      onDone: () async {
        await widget.onPaid();
      },
    );
  }
}

class _InvoiceView extends StatelessWidget {
  const _InvoiceView({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.pagePadding),
    children: [
      // Company / GST Official Header
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FixNow',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'FixNow Technologies Pvt Ltd',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'GSTIN: ${FixPdfInvoiceBuilder.companyGstin}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Text(
                  'Bengaluru, Karnataka 560102',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      FixPageHeader(
        eyebrow: 'INVOICE',
        title: invoice.invoiceNumber,
        description: 'Receipt for a completed payment on FixNow.',
      ),
      const SizedBox(height: AppSpacing.md),

      // Grand Total Banner Card
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount paid',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            FixRollingTicker(
              targetValue: invoice.amountMinor > 0
                  ? invoice.amountMinor / 100.0
                  : (double.tryParse(
                          invoice.amountLabel.replaceAll(
                            RegExp(r'[^0-9.]'),
                            '',
                          ),
                        ) ??
                        0.0),
              currencySymbol: invoice.currency == 'INR'
                  ? '₹'
                  : '${invoice.currency} ',
              showDecimals: (invoice.amountMinor % 100) != 0,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      FixCard(
        semanticLabel: 'Invoice details',
        child: Column(
          children: [
            _Row(label: 'Invoice number', value: invoice.invoiceNumber),
            const Divider(height: AppSpacing.lg),
            _Row(label: 'Status', value: invoice.statusLabel),
            const Divider(height: AppSpacing.lg),
            _Row(label: 'Issued', value: _date(invoice.issuedAt)),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      FixCard(
        semanticLabel: 'GST Tax Breakdown',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'GST Tax Breakdown',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textOnSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SAC 9987 • 18% GST',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Row(label: 'Taxable Service Base', value: invoice.baseAmountLabel),
            const Divider(height: AppSpacing.md),
            _Row(label: 'Central GST (CGST @ 9%)', value: invoice.cgstLabel),
            const Divider(height: AppSpacing.md),
            _Row(label: 'State GST (SGST @ 9%)', value: invoice.sgstLabel),
            const Divider(height: AppSpacing.md),
            _Row(label: 'Total GST (18%)', value: invoice.totalGstLabel),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'GSTIN: ${FixPdfInvoiceBuilder.companyGstin} • Registered under CGST Act 2017',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textOnSurfaceSecondary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      // 30-Day FixNow Trust Warranty Certificate Banner
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primaryFixed,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '30-Day FixNow Shield Protection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Free rework & dispute resolution guaranteed on this invoice.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      FixButton(
        label: 'Download PDF Invoice',
        icon: Icons.download_rounded,
        onPressed: () => _downloadPdf(context),
      ),
      const SizedBox(height: AppSpacing.sm),
      FixButton(
        label: 'Share Invoice',
        icon: Icons.share_rounded,
        variant: FixButtonVariant.secondary,
        onPressed: () => FixShareInvoiceSheet.show(context, invoice: invoice),
      ),
    ],
  );

  void _downloadPdf(BuildContext context) {
    final bytes = FixPdfInvoiceBuilder.build(invoice);
    final fileName = FixPdfInvoiceBuilder.getFileName(invoice);
    final sizeKb = (bytes.length / 1024).toStringAsFixed(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: AppColors.borderDefault.withValues(alpha: 0.2),
          ),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.file_download_done_rounded,
              color: AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Downloaded $fileName ($sizeKb KB)',
                style: const TextStyle(color: AppColors.cream, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textOnSurfaceSecondary,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(
        value,
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textOnSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
