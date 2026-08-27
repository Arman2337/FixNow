import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/cancellation_dialog.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'package:fixnow_mobile/design_system/fix_job_proof_dialog.dart';
import 'package:fixnow_mobile/features/provider/provider_active_job_cockpit_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProviderJobsScreen extends StatelessWidget {
  const ProviderJobsScreen({
    required this.controller,
    required this.showHistory,
    super.key,
  });

  final ProviderController controller;
  final bool showHistory;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final jobs = controller.jobs.where((job) {
        final finished = {'COMPLETED', 'CANCELLED'}.contains(job.status);
        return showHistory ? finished : !finished;
      }).toList();
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FixPageHeader(
              eyebrow: showHistory ? 'JOB HISTORY' : 'ACTIVE JOB',
              title: showHistory ? 'Completed work' : 'Assigned work',
              description: showHistory
                  ? 'A trustworthy record of completed and cancelled jobs.'
                  : 'Only valid actions for work assigned to your account are available.',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (jobs.isEmpty)
              FixCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.work_history_rounded,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        showHistory
                            ? 'No completed jobs yet.'
                            : 'No active assigned job right now.',
                      ),
                    ),
                  ],
                ),
              )
            else
              ...jobs.map(
                (job) => _JobCard(
                  job: job,
                  controller: controller,
                  readOnly: showHistory,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.controller,
    required this.readOnly,
  });

  final CustomerBooking job;
  final ProviderController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final action = switch (job.status) {
      'ASSIGNED' => ('Start journey', Icons.route_rounded),
      'EN_ROUTE' => ('Verify OTP to start', Icons.lock_open_rounded),
      'IN_PROGRESS' => ('Complete job', Icons.task_alt_rounded),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FixCard(
        tone: FixCardTone.elevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FixStatusChip(
                label: job.status.replaceAll('_', ' '),
                icon: Icons.verified_user_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              job.description,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _category(job.serviceCategoryId),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textOnDarkSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Requested ${_date(job.createdAt)} · Job #${_shortId(job.id)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (JobProofRepository.instance.getProof(job.id) case final proof?) ...[
              const SizedBox(height: AppSpacing.md),
              JobProofViewerCard(proof: proof),
            ],
            if (!readOnly) ...[
              const SizedBox(height: AppSpacing.md),
              FixButton(
                label: 'Open Full Job Cockpit',
                icon: Icons.dashboard_customize_rounded,
                variant: FixButtonVariant.secondary,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderActiveJobCockpitScreen(
                      job: job,
                      controller: controller,
                    ),
                  ),
                ),
              ),
            ],
            if (!readOnly && action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              FixButton(
                label: action.$1,
                icon: action.$2,
                onPressed: () async {
                  if (job.status == 'EN_ROUTE') {
                    final otp = await _requestServiceStartOtp(context);
                    if (otp != null) {
                      await controller.verifyOtpAndStartJob(job, otp);
                    }
                    return;
                  }
                  if (job.status == 'IN_PROGRESS') {
                    if (!JobProofRepository.instance.hasProof(job.id)) {
                      await JobProofVerificationDialog.show(
                        context,
                        bookingId: job.id,
                      );
                    }
                    await controller.advanceJob(job);
                    return;
                  }
                  await controller.advanceJob(job);
                },
              ),
            ],
            if (!readOnly && job.status == 'IN_PROGRESS') ...[
              const SizedBox(height: AppSpacing.sm),
              FixButton(
                label: 'Verification Photos',
                icon: Icons.camera_alt_outlined,
                variant: FixButtonVariant.secondary,
                onPressed: () => JobProofVerificationDialog.show(
                  context,
                  bookingId: job.id,
                  initialProof: JobProofRepository.instance.getProof(job.id),
                ),
              ),
            ],
            if (!readOnly && job.status == 'EN_ROUTE') ...[
              const SizedBox(height: AppSpacing.md),
              _LiveTrackingBlock(job: job, controller: controller),
              const SizedBox(height: AppSpacing.md),
              FixButton(
                label: controller.locationSharing[job.id] == true
                    ? 'Stop sharing location'
                    : 'Share live location',
                icon: Icons.my_location_rounded,
                variant: FixButtonVariant.secondary,
                onPressed: () => controller.setLocationConsent(
                  job,
                  controller.locationSharing[job.id] != true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FixButton(
                label: controller.isPublishingLocation(job.id)
                    ? 'Sending location...'
                    : 'Send current location',
                icon: Icons.location_searching_rounded,
                variant: FixButtonVariant.tertiary,
                isLoading: controller.isPublishingLocation(job.id),
                onPressed: controller.isPublishingLocation(job.id)
                    ? null
                    : () => controller.publishCurrentLocation(job),
              ),
              if (controller.actionError case final message?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(message, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
            if (!readOnly &&
                const {'ASSIGNED', 'EN_ROUTE'}.contains(job.status)) ...[
              const SizedBox(height: AppSpacing.md),
              _CancelJobButton(job: job, controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

String _category(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

String _shortId(String value) {
  final compact = value.replaceAll('-', '');
  final short = compact.length <= 8 ? compact : compact.substring(0, 8);
  return short.toUpperCase();
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

class _LiveTrackingBlock extends StatelessWidget {
  const _LiveTrackingBlock({required this.job, required this.controller});

  final CustomerBooking job;
  final ProviderController controller;

  @override
  Widget build(BuildContext context) {
    final sharing = controller.locationSharing[job.id] == true;
    final published = controller.locationPublished[job.id] == true;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE TRACKING',
            style: TextStyle(
              color: AppColors.textOnDarkSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                sharing
                    ? Icons.location_on_rounded
                    : Icons.location_off_outlined,
                color: sharing
                    ? AppColors.success
                    : AppColors.textOnDarkSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  sharing
                      ? 'Location sharing active'
                      : 'Location sharing is off',
                  style: const TextStyle(
                    color: AppColors.textOnDarkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            published
                ? 'Location shared successfully. Send an update when your position changes.'
                : sharing
                ? 'The customer can follow your arrival after your first update.'
                : 'Share your location while travelling so the customer can follow your arrival.',
            style: const TextStyle(color: AppColors.textOnDarkSecondary),
          ),
        ],
      ),
    );
  }
}

Future<String?> _requestServiceStartOtp(BuildContext context) async {
  final input = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.accentGold,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Verify customer OTP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textOnDarkPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Ask the customer for the 4-digit code shown in their FixNow booking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textOnDarkSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Customer OTP',
                style: TextStyle(
                  color: AppColors.textOnDarkPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: input,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setDialogState(() {}),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: '• • • •',
                  counterText: '',
                  hintStyle: TextStyle(
                    color: AppColors.inputHint,
                    letterSpacing: 4,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${input.text.length}/4 digits',
                  style: const TextStyle(color: AppColors.textOnDarkSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Never start work before the customer code is verified.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textOnDarkSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: RegExp(r'^\d{4}$').hasMatch(input.text.trim())
                          ? () {
                              final otp = input.text.trim();
                              Navigator.pop(dialogContext, otp);
                            }
                          : null,
                      child: const Text('Verify & start'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  input.dispose();
  return result;
}

class _CancelJobButton extends StatefulWidget {
  const _CancelJobButton({required this.job, required this.controller});
  final CustomerBooking job;
  final ProviderController controller;

  @override
  State<_CancelJobButton> createState() => _CancelJobButtonState();
}

class _CancelJobButtonState extends State<_CancelJobButton> {
  bool loading = false;
  String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error case final message?) ...[
        Text(message, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: AppSpacing.sm),
      ],
      FixButton(
        label: 'Cancel job',
        icon: Icons.cancel_outlined,
        variant: FixButtonVariant.destructive,
        isLoading: loading,
        onPressed: () async {
          final reason = await showCancellationDialog(context);
          if (reason == null) return;
          setState(() {
            loading = true;
            error = null;
          });
          try {
            await widget.controller.cancelJob(widget.job, reason);
          } catch (_) {
            if (mounted) {
              setState(() {
                loading = false;
                error =
                    'The job could not be cancelled. Refresh and try again.';
              });
            }
          }
        },
      ),
    ],
  );
}
