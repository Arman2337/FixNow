import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/features/emergency/emergency_controller.dart';
import 'package:fixnow_mobile/features/emergency/emergency_repository.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';

/// Policy §3 mandated copy. Fixed by docs/safety/emergency-dispatch-policy-v1;
/// callers cannot alter it.
const String kEmergencyNotice =
    'FixNow priority dispatch alerts nearby verified professionals for these '
    'home hazards. It is not an emergency service. If anyone is in danger, '
    'call your local emergency number first.';

/// FN-064: the deliberate confirmation step before an emergency alert is
/// sent. Built for stress: few fields, large targets, plain words, and the
/// public-emergency guidance always visible (FR-EMG-001/002, NFR-ACC-003).
class EmergencyConfirmScreen extends StatefulWidget {
  const EmergencyConfirmScreen({
    required this.categories,
    required this.repository,
    this.locationProvider,
    super.key,
  }) : assert(categories.length > 0);

  final List<ServiceCategory> categories;
  final EmergencyRepository repository;
  final BookingLocationProvider? locationProvider;

  @override
  State<EmergencyConfirmScreen> createState() => _EmergencyConfirmScreenState();
}

class _EmergencyConfirmScreenState extends State<EmergencyConfirmScreen> {
  late final EmergencyController _controller;
  late ServiceCategory _selected;
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.categories.first;
    _controller = EmergencyController(widget.repository)
      ..addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency'),
        backgroundColor: AppColors.backgroundPrimary,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _controller.state ==
                EmergencyFlowState.dispatched
            ? _DispatchedView(controller: _controller)
            : FixPageFrame(
                child: ListView(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _noticeCard(context),
                    const SizedBox(height: AppSpacing.lg),
                    if (widget.categories.length > 1)
                      ..._categoryPicker(context)
                    else
                      _categoryHeader(context, widget.categories.first),
                    const SizedBox(height: AppSpacing.lg),
                    _descriptionCard(context),
                    const SizedBox(height: AppSpacing.md),
                    if (_controller.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    _confirmButton(context),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _noticeCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger, width: 1.2),
        ),
        child: Semantics(
          container: true,
          label: 'Emergency service limitation notice',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  kEmergencyNotice,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _categoryHeader(BuildContext context, ServiceCategory category) =>
      FixCard(
        tone: FixCardTone.secondary,
        semanticLabel: '${category.name} emergency selected',
        child: Row(
          children: [
            const Icon(Icons.emergency_rounded, color: AppColors.danger),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '${category.name} — ${category.description ?? 'safety hazard'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );

  List<Widget> _categoryPicker(BuildContext context) => [
        Text(
          'What kind of hazard?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final category in widget.categories)
              ChoiceChip(
                label: Text(category.name),
                selected: _selected.id == category.id,
                onSelected: (_) => setState(() => _selected = category),
              ),
          ],
        ),
      ];

  Widget _descriptionCard(BuildContext context) => FixCard(
        tone: FixCardTone.secondary,
        semanticLabel: 'Describe the emergency',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What is happening?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'For example: strong smell of gas in the kitchen.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      );

  Widget _confirmButton(BuildContext context) {
    final busy =
        _controller.state == EmergencyFlowState.creating ||
            _controller.state == EmergencyFlowState.resolvingLocation;
    final ready = _description.text.trim().isNotEmpty && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FixButton(
          label: busy ? 'Sending…' : 'Send emergency alert',
          onPressed: ready
              ? () async {
                  FocusScope.of(context).unfocus();
                  await _controller.confirmAndDispatch(
                    serviceCategoryId: _selected.id,
                    description: _description.text,
                    locationProvider:
                        widget.locationProvider ?? BookingLocationResolver(),
                  );
                }
              : null,
          expand: true,
          height: 56,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Alerts only verified professionals near you. '
          'No response time is guaranteed.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DispatchedView extends StatelessWidget {
  const _DispatchedView({required this.controller});

  final EmergencyController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    return FixPageFrame(
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.sm),
          const Icon(Icons.emergency_rounded, color: AppColors.danger, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Alert sent',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            status == null
                ? 'Contacting professionals near you…'
                : 'Alerting verified professionals nearby — wave ${status.currentWave}.',
            textAlign: TextAlign.center,
            semanticsLabel: 'Emergency alert progress',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (controller.showFallback && status != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      status.guidance ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Keep this screen open or check Bookings — you will see the moment a professional accepts.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.lg),
          FixButton(
            label: 'Done',
            variant: FixButtonVariant.secondary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You can cancel any time from your Bookings list while no professional is on the way.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
