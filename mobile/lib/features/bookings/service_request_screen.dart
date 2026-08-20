import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';

enum ServiceUrgency { normal, urgent, emergency }

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({
    required this.category,
    required this.controller,
    this.locationProvider,
    super.key,
  });
  final ServiceCategory category;
  final BookingController controller;
  final BookingLocationProvider? locationProvider;

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  ServiceUrgency _urgency = ServiceUrgency.normal;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _addSuggestion(String text) {
    if (_details.text.isEmpty) {
      _details.text = text;
    } else {
      _details.text = '${_details.text.trim()}, $text';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final location =
          await (widget.locationProvider ?? BookingLocationResolver())
              .resolve();
      await widget.controller.create(
        serviceCategoryId: widget.category.id,
        description: _details.text,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on BookingLocationFailure catch (error) {
      setState(() => _error = error.message);
    } on ApiException catch (error) {
      debugPrint('ApiException during request creation: ${error.kind} - ${error.message}');
      setState(
        () => _error = error.kind == ApiFailureKind.offline
            ? 'You are offline. Reconnect and try again.'
            : 'We could not create the request. Try again.',
      );
    } catch (e, stackTrace) {
      debugPrint('Error creating request: $e\n$stackTrace');
      setState(() => _error = 'We could not create the request. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request service'), centerTitle: false),
    body: SafeArea(
      child: FixPageFrame(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            FixPageHeader(
              eyebrow: 'FAST, SECURE MATCHING',
              title: widget.category.name,
              description:
                  widget.category.description ??
                  'Tell us what needs attention and we will match a verified provider nearby.',
            ),
            const SizedBox(height: AppSpacing.lg),

            const FixCard(
              tone: FixCardTone.elevated,
              semanticLabel: 'How matching works',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.verified),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Your request is shared only with eligible providers. A provider is assigned after they accept it.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What needs fixing?',
                    style: TextStyle(
                      color: AppColors.textOnDarkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextFormField(
                    controller: _details,
                    style: const TextStyle(color: AppColors.inputText),
                    cursorColor: AppColors.primary,
                    enabled: !_submitting,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'Describe the issue (e.g. pipe leak, low pressure, installation)...',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 10
                        ? 'Add at least 10 characters so the provider can prepare.'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            const Row(
              children: [
                Icon(Icons.location_on_outlined, size: 20, color: AppColors.accentGold),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your current location is captured only when you submit.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (_error case final message?) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FixPrimaryButton(
              label: 'Find a verified provider',
              icon: Icons.arrow_forward_rounded,
              onPressed: _submit,
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildChip(String label) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surfaceSecondary,
      side: const BorderSide(color: AppColors.borderDefault),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      onPressed: () => _addSuggestion(label),
    );
  }

  Widget _buildUrgencyCard({
    required ServiceUrgency urgency,
    required String title,
    required String time,
    required IconData icon,
    bool isEmergency = false,
  }) {
    final selected = _urgency == urgency;
    final activeColor = isEmergency ? AppColors.emergency : AppColors.primary;
    final bgColor = selected
        ? (isEmergency ? AppColors.emergencySoft : AppColors.primarySoft)
        : AppColors.surfacePrimary;
    final borderColor = selected ? activeColor : AppColors.borderDefault;

    return InkWell(
      onTap: () => setState(() => _urgency = urgency),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? activeColor : AppColors.textSecondary, size: 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: selected
                    ? activeColor
                    : AppColors.textOnLightPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                color: selected ? activeColor : AppColors.textOnLightMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
