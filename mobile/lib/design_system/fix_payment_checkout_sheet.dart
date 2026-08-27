import 'dart:math' as math;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:flutter/material.dart';

/// Supported payment methods in FixNow.
enum PaymentMethodType {
  upi,
  card,
  cash,
  wallet,
}

/// A world-class interactive mobile checkout sheet with UPI, Card, Cash on Delivery,
/// optional technician tipping, and a celebratory 60fps payment success animation.
class FixPaymentCheckoutSheet extends StatefulWidget {
  const FixPaymentCheckoutSheet({
    required this.bookingId,
    required this.baseAmountMinor,
    this.sparePartsMinor = 0,
    this.currency = 'INR',
    this.proName = 'Verified Pro',
    this.onProcessPayment,
    this.onViewInvoice,
    this.onDone,
    super.key,
  });

  final String bookingId;
  final int baseAmountMinor;
  final int sparePartsMinor;
  final String currency;
  final String proName;

  /// Payment execution callback.
  final Future<void> Function({
    required String paymentMethod,
    required int totalMinor,
    required int tipMinor,
  })? onProcessPayment;

  final VoidCallback? onViewInvoice;
  final VoidCallback? onDone;

  /// Helper to show this sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String bookingId,
    required int baseAmountMinor,
    int sparePartsMinor = 0,
    String currency = 'INR',
    String proName = 'Verified Pro',
    Future<void> Function({
      required String paymentMethod,
      required int totalMinor,
      required int tipMinor,
    })? onProcessPayment,
    VoidCallback? onViewInvoice,
    VoidCallback? onDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FixPaymentCheckoutSheet(
        bookingId: bookingId,
        baseAmountMinor: baseAmountMinor,
        sparePartsMinor: sparePartsMinor,
        currency: currency,
        proName: proName,
        onProcessPayment: onProcessPayment,
        onViewInvoice: onViewInvoice,
        onDone: onDone,
      ),
    );
  }

  @override
  State<FixPaymentCheckoutSheet> createState() =>
      _FixPaymentCheckoutSheetState();
}

class _FixPaymentCheckoutSheetState extends State<FixPaymentCheckoutSheet>
    with SingleTickerProviderStateMixin {
  PaymentMethodType _selectedMethod = PaymentMethodType.upi;
  int _selectedTipMinor = 0; // in paise
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _errorMessage;

  late final AnimationController _successController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );

    _checkAnimation = CurvedAnimation(
      parent: _successController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  int get _subtotalMinor => widget.baseAmountMinor + widget.sparePartsMinor;
  int get _gstMinor => (_subtotalMinor * 0.18).round();
  int get _grandTotalMinor => _subtotalMinor + _gstMinor + _selectedTipMinor;

  String _formatPaise(int minor) {
    final rupees = minor / 100;
    return '₹${rupees.toStringAsFixed(minor % 100 == 0 ? 0 : 2)}';
  }

  Future<void> _handlePay() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (widget.onProcessPayment != null) {
        await widget.onProcessPayment!(
          paymentMethod: _selectedMethod.name,
          totalMinor: _grandTotalMinor,
          tipMinor: _selectedTipMinor,
        );
      } else {
        // Fallback simulate quick confirmation
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations) {
        _successController.value = 1.0;
      } else {
        _successController.forward(from: 0.0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _isSuccess ? _buildSuccessView() : _buildCheckoutView(),
        ),
      ),
    );
  }

  Widget _buildCheckoutView() {
    return Column(
      key: const ValueKey('checkout_form'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checkout & Pay',
                    style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, size: 13, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        '100% Safe & Encrypted • FixNow Guarantee',
                        style: AppTypography.caption.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        const Divider(color: Colors.white12, height: 20),

        // Scrollable content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error Alert if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Cost Breakdown Card
                _buildBillSummary(),

                const SizedBox(height: AppSpacing.lg),

                // Tip Technician
                _buildTipSection(),

                const SizedBox(height: AppSpacing.lg),

                // Payment Method Selector
                _buildPaymentMethodSection(),

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),

        // Sticky Bottom Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.backgroundSecondary,
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL PAYABLE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      _formatPaise(_grandTotalMinor),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FixButton(
                  label: _selectedMethod == PaymentMethodType.cash
                      ? 'Confirm Cash Pay'
                      : 'Pay ${_formatPaise(_grandTotalMinor)}',
                  icon: _selectedMethod == PaymentMethodType.cash
                      ? Icons.handshake_rounded
                      : Icons.lock_rounded,
                  isLoading: _isProcessing,
                  onPressed: _handlePay,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillSummary() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Service Cost Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.proName,
                  style: const TextStyle(color: AppColors.focus, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 16),
          _buildRow('Base Service & Labour', _formatPaise(widget.baseAmountMinor)),
          if (widget.sparePartsMinor > 0)
            _buildRow('Approved Spare Parts', _formatPaise(widget.sparePartsMinor)),
          _buildRow('GST (18% Goods & Services Tax)', _formatPaise(_gstMinor)),
          if (_selectedTipMinor > 0)
            _buildRow('Technician Appreciation Tip', _formatPaise(_selectedTipMinor),
                valueColor: AppColors.accentGold),
          const Divider(color: Colors.white10, height: 14),
          _buildRow('Total Amount', _formatPaise(_grandTotalMinor),
              valueColor: AppColors.focus, isBold: true),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isBold ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              fontSize: isBold ? 14 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite_rounded, size: 16, color: AppColors.accentGold),
            const SizedBox(width: 6),
            Text(
              'Tip Your Technician (Optional)',
              style: AppTypography.title.copyWith(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          '100% of your tip goes directly to your service professional.',
          style: TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          children: [
            _buildTipChip('No Tip', 0),
            _buildTipChip('+₹30', 3000),
            _buildTipChip('+₹50 ⭐', 5000),
            _buildTipChip('+₹100 🎉', 10000),
          ],
        ),
      ],
    );
  }

  Widget _buildTipChip(String label, int minor) {
    final isSelected = _selectedTipMinor == minor;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedTipMinor = minor);
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.white12,
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Payment Method',
          style: AppTypography.title.copyWith(color: AppColors.textPrimary, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildMethodCard(
          type: PaymentMethodType.upi,
          icon: Icons.flash_on_rounded,
          title: 'UPI (Fast & 1-Tap)',
          subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
          badge: 'POPULAR',
        ),
        const SizedBox(height: 8),
        _buildMethodCard(
          type: PaymentMethodType.card,
          icon: Icons.credit_card_rounded,
          title: 'Credit / Debit Card',
          subtitle: 'Visa, MasterCard, RuPay (256-Bit SSL)',
        ),
        const SizedBox(height: 8),
        _buildMethodCard(
          type: PaymentMethodType.cash,
          icon: Icons.payments_outlined,
          title: 'Cash on Delivery (Pay to Pro)',
          subtitle: 'Pay exact cash upon inspection of completed work',
        ),
        const SizedBox(height: 8),
        _buildMethodCard(
          type: PaymentMethodType.wallet,
          icon: Icons.account_balance_wallet_rounded,
          title: 'FixNow Wallet',
          subtitle: 'Balance: ₹250 available',
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required PaymentMethodType type,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
  }) {
    final isSelected = _selectedMethod == type;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = type),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: AppColors.onAccentGold,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary : Colors.white30,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Celebratory 60fps Success View
  Widget _buildSuccessView() {
    return Padding(
      key: const ValueKey('success_celebration'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),

          // Animated Circular Badge with Custom Drawn Checkmark
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _checkAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CheckmarkPainter(progress: _checkAnimation.value),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Payment Successful!',
            style: AppTypography.heading1.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            _formatPaise(_grandTotalMinor),
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          Text(
            'Paid to ${widget.proName} via ${_selectedMethod == PaymentMethodType.cash ? 'Cash on Delivery' : 'Instant Checkout'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Receipt details card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Transaction Ref', 'TXN-${widget.bookingId.substring(0, math.min(8, widget.bookingId.length)).toUpperCase()}'),
                _buildReceiptRow('Booking ID', widget.bookingId),
                _buildReceiptRow('Status', 'VERIFIED & PAID', valueColor: AppColors.success),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // CTAs
          Row(
            children: [
              if (widget.onViewInvoice != null)
                Expanded(
                  child: FixSecondaryButton(
                    label: 'View Invoice',
                    icon: Icons.receipt_long_rounded,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onViewInvoice!();
                    },
                  ),
                ),
              if (widget.onViewInvoice != null) const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FixButton(
                  label: 'Done',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDone?.call();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for drawing the checkmark stroke progressively
class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final start = Offset(size.width * 0.28, size.height * 0.52);
    final mid = Offset(size.width * 0.44, size.height * 0.68);
    final end = Offset(size.width * 0.74, size.height * 0.36);

    path.moveTo(start.dx, start.dy);

    if (progress <= 0.5) {
      final p = progress / 0.5;
      path.lineTo(
        start.dx + (mid.dx - start.dx) * p,
        start.dy + (mid.dy - start.dy) * p,
      );
    } else {
      path.lineTo(mid.dx, mid.dy);
      final p = (progress - 0.5) / 0.5;
      path.lineTo(
        mid.dx + (end.dx - mid.dx) * p,
        mid.dy + (end.dy - mid.dy) * p,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
