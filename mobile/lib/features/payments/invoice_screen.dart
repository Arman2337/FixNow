import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_payment_checkout_sheet.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
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
    this.localPaymentRepository,
    bool? localPaymentBypassEnabled,
    super.key,
  }) : localPaymentBypassEnabled =
           localPaymentBypassEnabled ?? LocalPaymentConfig.bypassEnabled;

  final InvoiceRepository repository;
  final String bookingId;

  /// FN-118: dev-only local checkout. When null the pay affordance never
  /// shows; production and non-dev builds simply pass nothing here.
  final LocalPaymentRepository? localPaymentRepository;

  /// Defaults to `LocalPaymentConfig.bypassEnabled`; injectable for tests.
  final bool localPaymentBypassEnabled;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  late final InvoiceController _controller =
      InvoiceController(widget.repository, widget.bookingId)..load();

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
          if (_canPayLocally) ...[
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              label: 'Pay Now (Interactive Checkout)',
              icon: Icons.payments_rounded,
              onPressed: () => _openCheckoutSheet(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            FixSecondaryButton(
              label: 'Complete payment (local)',
              icon: Icons.build_circle_outlined,
              isLoading: _paying,
              onPressed: _payLocally,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Local testing only — drives the fake gateway to a paid '
              'invoice. Not available in production.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textOnSurfaceSecondary),
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
      onProcessPayment: ({
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
      FixPageHeader(
        eyebrow: 'INVOICE',
        title: invoice.invoiceNumber,
        description: 'Receipt for a completed payment on FixNow.',
      ),
      const SizedBox(height: AppSpacing.lg),
      FixCard(
        tone: FixCardTone.elevated,
        semanticLabel: 'Invoice amount ${invoice.amountLabel}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount paid',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textOnLightSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              invoice.amountLabel,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.textOnLightPrimary,
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
    ],
  );

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
      Text(label, style: Theme.of(context).textTheme.bodyLarge),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textOnSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}
