import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/payments/gateway_checkout_repository.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GatewayCheckoutActions extends StatefulWidget {
  const GatewayCheckoutActions({
    required this.repository,
    required this.serviceId,
    required this.refresh,
    this.group = false,
    super.key,
  });

  final GatewayCheckoutRepository repository;
  final String serviceId;
  final Future<void> Function() refresh;
  final bool group;

  @override
  State<GatewayCheckoutActions> createState() => _GatewayCheckoutActionsState();
}

class _GatewayCheckoutActionsState extends State<GatewayCheckoutActions> {
  bool _busy = false;
  bool _opened = false;

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      if (widget.group) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Pay for your household'),
            content: const Text(
              'Confirm that your household received the service before paying.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('I received the service'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      final uri = await widget.repository.start(
        widget.serviceId,
        group: widget.group,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Continue to Razorpay'),
          content: const Text(
            'Approve payment in your UPI app. Return to FixNow to check confirmation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                    webOnlyWindowName: '_blank',
                  );
                  if (!launched) throw StateError('Checkout could not open');
                  if (mounted) setState(() => _opened = true);
                  if (dialog.mounted) Navigator.pop(dialog);
                } catch (_) {
                  _showError('Could not open checkout. Try again.');
                }
              },
              child: const Text('Open secure checkout'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_opened)
        const Text('Payment stays pending until Razorpay confirms the charge.'),
      FixButton(
        label: _opened ? 'Reopen UPI checkout' : 'Pay with UPI',
        icon: Icons.payments_outlined,
        onPressed: _busy ? null : _start,
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        onPressed: _busy ? null : widget.refresh,
        child: const Text('Check payment status'),
      ),
    ],
  );
}
