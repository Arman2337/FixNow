import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_price_breakdown_card.dart';
import 'package:fixnow_mobile/design_system/signature_motion.dart';
import 'package:fixnow_mobile/design_system/fix_address_selector.dart';
import 'package:fixnow_mobile/design_system/fix_schedule_picker.dart';
import 'package:fixnow_mobile/features/ai/price_estimate_repository.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_schedule.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:fixnow_mobile/features/location/service_location_picker_sheet.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({
    required this.category,
    required this.controller,
    this.locationProvider,
    this.initialLocation,
    this.initialDescription,
    this.estimateRepository,
    super.key,
  });
  final ServiceCategory category;
  final BookingController controller;
  final BookingLocationProvider? locationProvider;
  final BookingLocationFix? initialLocation;

  /// Prefill from a previous booking ("Book again"); always reviewable and
  /// editable before submission.
  final String? initialDescription;

  /// FN-113: optional advisory price estimate source. When absent (or when a
  /// fetch fails) the static published-price card stays as-is.
  final PriceEstimateRepository? estimateRepository;

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  bool _submitting = false;
  bool _showRadar = false;
  String? _error;
  BookingLocationFix? _confirmedLocation;
  BookingSchedule? _schedule;
  PriceEstimateController? _estimate;

  String? _createdBookingId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onBookingChanged);
    _details.text = widget.initialDescription ?? '';
    final defaultAddr = SavedAddressRepository.instance.defaultAddress;
    if (defaultAddr != null &&
        widget.initialLocation == null &&
        widget.locationProvider == null) {
      _confirmedLocation = BookingLocationFix(
        latitude: defaultAddr.latitude,
        longitude: defaultAddr.longitude,
        accuracyMeters: 10,
        timestamp: DateTime.now(),
      );
    }
    final repository = widget.estimateRepository;
    if (repository != null) {
      _estimate = PriceEstimateController(repository)
        ..addListener(_onEstimateChanged)
        ..load(widget.category.id);
    }
  }

  void _onEstimateChanged() {
    if (mounted) setState(() {});
  }

  void _onBookingChanged() {
    if (!mounted || _createdBookingId == null || !_showRadar) return;
    final booking = widget.controller.bookings
        .where((b) => b.id == _createdBookingId)
        .firstOrNull;
    if (booking != null &&
        const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}.contains(booking.status)) {
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(booking);
      }
    }
  }

  /// FN-113: the price card shows the advisory estimate when one is
  /// available and otherwise falls back to the static published-price
  /// content. The estimate never blocks booking and is labelled advisory.
  Widget _buildPriceContent(BuildContext context) {
    final estimate = _estimate?.estimate;
    if (_estimate?.state == PriceEstimateState.ready &&
        estimate != null &&
        estimate.kind != PriceEstimateKind.priceOnRequest) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated price',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            estimate.rangeLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            estimate.sampleSize == null
                ? estimate.explanation
                : '${estimate.explanation} Typically ${estimate.typicalLabel}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Advisory only — the final charge is confirmed for your booking '
            'before payment.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textOnSurfaceSecondary,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base price',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.category.pricing?.displayLabel ?? 'Price on request',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (widget.category.pricing != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Final quote is confirmed by the provider after inspection.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBookingChanged);
    _estimate?.dispose();
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
          _confirmedLocation ??
          await (widget.locationProvider ??
                  BookingLocationResolver(initialFix: widget.initialLocation))
              .resolve();
      final booking = await widget.controller.create(
        serviceCategoryId: widget.category.id,
        description: _details.text,
        latitude: location.latitude,
        longitude: location.longitude,
        scheduledAt: _schedule?.targetScheduledAt,
      );
      if (mounted) {
        setState(() {
          _createdBookingId = booking.id;
          _showRadar = true;
        });
      }
    } on BookingLocationFailure {
      // A browser may have permission but no hardware location source. Let the
      // customer choose the service address rather than showing a dead end.
      if (mounted) setState(() => _submitting = false);
      await _chooseLocationOnMap();
      if (_confirmedLocation != null && mounted) {
        await _submit();
      }
    } on ApiException catch (error) {
      debugPrint(
        'ApiException during request creation: ${error.kind} - ${error.message}',
      );
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
  Widget build(BuildContext context) {
    if (_showRadar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request service'),
          centerTitle: false,
        ),
        body: MatchRadarView(
          categoryName: widget.category.name,
          onFinished: () {
            if (!mounted) return;
            final booking = widget.controller.bookings
                .where((b) => b.id == _createdBookingId)
                .firstOrNull;
            if (booking != null &&
                const {'ASSIGNED', 'EN_ROUTE', 'IN_PROGRESS'}
                    .contains(booking.status)) {
              Navigator.of(context).pop(booking);
            } else {
              Navigator.of(context).pop(true);
            }
          },
        ),
      );
    }
    return Scaffold(
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
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.verified,
                    ),
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

              FixCard(
                tone: FixCardTone.elevated,
                semanticLabel: 'Base service price',
                child: Row(
                  children: [
                    Icon(
                      Icons.sell_outlined,
                      color: widget.category.pricing == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _buildPriceContent(context)),
                  ],
                ),
              ),
              if (widget.category.pricing != null) ...[
                const SizedBox(height: AppSpacing.md),
                FixPriceBreakdownCard(
                  amountMinor: widget.category.pricing!.amountMinor,
                  currency: widget.category.pricing!.currency,
                  modelType: PricingModelType.fixed,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              FixCard(
                tone: FixCardTone.secondary,
                semanticLabel: 'Describe your service request',
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tell us what needs fixing',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.textOnSurface),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Clear details help the right professional prepare before they accept.',
                        style: TextStyle(
                          color: AppColors.textOnSurfaceSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        'Issue details',
                        style: TextStyle(
                          color: AppColors.textOnSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
                              'For example: a pipe is leaking under the sink and water pressure is low.',
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Add at least 10 characters so the provider can prepare.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Add a quick detail',
                        style: TextStyle(
                          color: AppColors.textOnSurfaceSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _buildChip('Leak or water damage'),
                          _buildChip('Needs urgent attention'),
                          _buildChip('Installation or replacement'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              SavedAddressSelectorCard(
                onAddressSelected: (addr) {
                  setState(() {
                    _confirmedLocation = BookingLocationFix(
                      latitude: addr.latitude,
                      longitude: addr.longitude,
                      accuracyMeters: 10,
                      timestamp: DateTime.now(),
                    );
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),

              FixSchedulePickerCard(
                initialSchedule: _schedule,
                onScheduleChanged: (sched) {
                  setState(() => _schedule = sched);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              const Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: AppColors.accentGold,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your current location is captured only when you submit.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FixSecondaryButton(
                label: _confirmedLocation == null
                    ? 'Choose service location on map'
                    : 'Service location selected on map',
                icon: Icons.map_outlined,
                onPressed: _submitting ? null : _chooseLocationOnMap,
              ),
              if (_error case final message?) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
  }

  Widget _buildChip(String label) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surfaceSecondary,
      side: const BorderSide(color: AppColors.borderDefault),
      labelStyle: const TextStyle(
        color: AppColors.textOnSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onPressed: () => _addSuggestion(label),
    );
  }

  Future<void> _chooseLocationOnMap() async {
    final selected = await ServiceLocationPickerSheet.show(
      context,
      initialLocation: widget.initialLocation ?? _confirmedLocation,
    );
    if (selected != null && mounted) {
      setState(() {
        _confirmedLocation = selected;
        _error = null;
      });
    }
  }
}
