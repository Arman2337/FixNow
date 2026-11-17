import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/payments/gateway_checkout_actions.dart';
import 'package:fixnow_mobile/features/payments/gateway_checkout_repository.dart';
import 'package:flutter/material.dart';

class GroupServicePayment extends StatefulWidget {
  const GroupServicePayment({
    required this.repository,
    required this.groupId,
    required this.amountMinor,
    super.key,
  });

  final GatewayCheckoutRepository repository;
  final String groupId;
  final int amountMinor;

  @override
  State<GroupServicePayment> createState() => _GroupServicePaymentState();
}

class _GroupServicePaymentState extends State<GroupServicePayment> {
  late Future<(bool, String?)> _payment = _load();

  Future<(bool, String?)> _load() async {
    final available = await widget.repository.isAvailable();
    final status = await widget.repository.groupStatus(widget.groupId);
    return (available, status);
  }

  Future<void> _refresh() async {
    setState(() => _payment = _load());
  }

  @override
  Widget build(BuildContext context) => FixCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your household payment',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('₹${(widget.amountMinor / 100).toStringAsFixed(2)}'),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<(bool, String?)>(
          future: _payment,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Text('Checking payment status…');
            }
            if (snapshot.hasError) {
              return TextButton(
                onPressed: _refresh,
                child: const Text('Retry payment status'),
              );
            }
            final (available, status) = snapshot.data!;
            if (status == 'PAID') return const Text('Payment confirmed');
            if (!available) {
              return const Text('Online UPI checkout is unavailable.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status == 'CREATED')
                  const Text('Awaiting payment confirmation.'),
                if (status == 'FAILED')
                  const Text('The last attempt failed. You can try again.'),
                GatewayCheckoutActions(
                  repository: widget.repository,
                  serviceId: widget.groupId,
                  group: true,
                  refresh: _refresh,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
