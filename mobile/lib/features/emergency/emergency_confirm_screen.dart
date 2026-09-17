import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/signature_motion.dart';
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
/// Aligned strictly with Stitch reference: FixNow_-_Emergency_Hazards_Priority_SOS.html
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevated,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Dialing 24/7 Priority Emergency Hotline: 1800-123-4567',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.phone_in_talk_rounded,
                size: 14,
                color: AppColors.error,
              ),
              label: const Text(
                '24/7 Hotline',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) =>
            _controller.state == EmergencyFlowState.dispatched
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

  /// 1. Critical Evacuation Advisory Card (Life Safety Notice)
  Widget _noticeCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.errorContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.error.withValues(alpha: 0.25),
        width: 1.2,
      ),
    ),
    child: Semantics(
      container: true,
      label: 'Emergency service limitation notice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'LIFE SAFETY NOTICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'IMMEDIATE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kEmergencyNotice,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: AppColors.onErrorContainer,
            ),
          ),
        ],
      ),
    ),
  );

  /// Single Category Header
  Widget _categoryHeader(BuildContext context, ServiceCategory category) =>
      FixCard(
        tone: FixCardTone.secondary,
        semanticLabel: '${category.name} emergency selected',
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getHazardIcon(category.name),
                color: AppColors.onError,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${category.name} — ${category.description ?? 'safety hazard'}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  /// 2. Emergency Hazard Selection Grid
  List<Widget> _categoryPicker(BuildContext context) => [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          'Select Critical Hazard',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'Tap to swap trigger',
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    ),
    const SizedBox(height: AppSpacing.xs),
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

  IconData _getHazardIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('electric') || lower.contains('spark')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('plumb') ||
        lower.contains('water') ||
        lower.contains('flood')) {
      return Icons.water_damage_rounded;
    }
    if (lower.contains('gas') || lower.contains('leak')) {
      return Icons.air_rounded;
    }
    return Icons.local_fire_department_rounded;
  }

  /// Description Input
  Widget _descriptionCard(BuildContext context) => FixCard(
    tone: FixCardTone.secondary,
    semanticLabel: 'Describe the emergency',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What is happening?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
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

  /// 5. Hold to Confirm Safety Trigger
  Widget _confirmButton(BuildContext context) {
    final busy =
        _controller.state == EmergencyFlowState.creating ||
        _controller.state == EmergencyFlowState.resolvingLocation;
    final ready = _description.text.trim().isNotEmpty && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!ready && !busy)
          FixButton(
            label: 'Send emergency alert',
            onPressed: null,
            expand: true,
            height: 56,
          )
        else
          HoldToConfirmButton(
            key: const ValueKey('emergency-hold'),
            label: busy ? 'Sending…' : 'Hold to send emergency alert',
            onConfirmed: () async {
              FocusScope.of(context).unfocus();
              await _controller.confirmAndDispatch(
                serviceCategoryId: _selected.id,
                description: _description.text,
                locationProvider:
                    widget.locationProvider ?? BookingLocationResolver(),
              );
            },
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

/// Concentric Radar sweep widget with radar circles and tech pings
class _RadarSweepBox extends StatelessWidget {
  const _RadarSweepBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar concentric circles & crosshairs
          CustomPaint(
            size: const Size(double.infinity, 130),
            painter: _RadarGridPainter(),
          ),
          // Center Beacon
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  color: AppColors.onPrimary,
                  size: 15,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'YOUR LOCATION',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          // Dispersed Tech Pings
          Positioned(
            top: 12,
            left: 20,
            child: _techPingBadge('Tech #104 (0.8 km)'),
          ),
          Positioned(
            bottom: 14,
            right: 20,
            child: _techPingBadge('Tech #88 (1.4 km)'),
          ),
          Positioned(
            top: 20,
            right: 28,
            child: _techPingBadge('Tech #41 (2.2 km)'),
          ),
        ],
      ),
    );
  }

  Widget _techPingBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);

    // Concentric rings
    canvas.drawCircle(center, 22, paint);
    canvas.drawCircle(center, 44, paint);
    canvas.drawCircle(center, 64, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.error, width: 2),
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: AppColors.error,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Alert sent',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status == null
                ? 'Contacting professionals near you…'
                : 'Alerting verified professionals nearby — wave ${status.currentWave}.',
            textAlign: TextAlign.center,
            semanticsLabel: 'Emergency alert progress',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (controller.showFallback && status != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger, width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      status.guidance ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Keep this screen open or check Bookings — you will see the moment a professional accepts.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Pro Radar Network
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Pro Radar Network',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '15-Min SLA',
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
                const _RadarSweepBox(),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cell_tower,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Wave ${status?.currentWave ?? 1} Broadcast: ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '5 Verified Techs nearby',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Pinned Address
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.pin_drop_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'DISPATCH ADDRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Flat 402, Green Glen Layout, Bellandur, Bengaluru',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.signpost_rounded,
                        size: 15,
                        color: AppColors.tertiary,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Landmark: Behind HDFC Bank ATM, Gate 2 (Intercom 402)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Public Helplines
          Row(
            children: [
              Expanded(
                child: _helplineCard(
                  number: '100',
                  label: 'Police',
                  icon: Icons.local_police_rounded,
                  iconColor: AppColors.primary,
                  bgColor: AppColors.surfaceContainerHigh,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _helplineCard(
                  number: '101',
                  label: 'Fire Force',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppColors.error,
                  bgColor: AppColors.errorContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _helplineCard(
                  number: '108',
                  label: 'Ambulance',
                  icon: Icons.medical_services_rounded,
                  iconColor: AppColors.tertiaryContainer,
                  bgColor: AppColors.surfaceContainerHigh,
                ),
              ),
            ],
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  static Widget _helplineCard({
    required String number,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            number,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
