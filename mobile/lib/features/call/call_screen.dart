import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';

/// Opens the device phone app. This build has no in-app audio transport, so it
/// never shows a connected state, call timer, or cosmetic microphone controls.
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.oppositePartyName,
    required this.oppositePartyRole,
    this.phoneNumber,
    this.bookingId,
    this.isProvider = false,
    this.controller,
  });

  final String oppositePartyName;
  final String oppositePartyRole;
  final String? phoneNumber;
  final String? bookingId;
  final bool isProvider;
  final CallController? controller;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _opening = false;
  String? _message;
  bool _failed = false;

  Future<void> _openPhoneApp() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _message = null;
    });
    final opened = widget.controller != null
        ? await widget.controller!.launchCall(widget.phoneNumber ?? '')
        : await CallController.launchPhoneCall(widget.phoneNumber ?? '');
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failed = !opened;
      _message = opened
          ? 'Phone app opened. Complete your call there.'
          : 'Could not open the phone app. Check that calling is available on this device and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasNumber = CallController.phoneUri(widget.phoneNumber ?? '') != null;
    final isCustomer =
        widget.isProvider ||
        widget.oppositePartyRole.toLowerCase().contains('customer');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Call')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.oppositePartyName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text(widget.oppositePartyRole.toUpperCase())),
                  if (!isCustomer) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Calls use your device phone app. Carrier charges may apply. In-app audio calling is not available in this build.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!hasNumber)
                const Text(
                  'A callable phone number is not available for this booking. Use booking chat to contact the other person.',
                  textAlign: TextAlign.center,
                ),
              if (hasNumber)
                FilledButton.icon(
                  onPressed: _opening ? null : _openPhoneApp,
                  icon: const Icon(Icons.phone_rounded),
                  label: Text(
                    _opening ? 'Opening phone app…' : 'Open phone app',
                  ),
                ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _failed
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
