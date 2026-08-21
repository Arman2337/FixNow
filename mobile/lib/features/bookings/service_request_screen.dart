import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({
    required this.category,
    required this.controller,
    this.locationProvider,
    this.initialLocation,
    super.key,
  });
  final ServiceCategory category;
  final BookingController controller;
  final BookingLocationProvider? locationProvider;
  final BookingLocationFix? initialLocation;

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  bool _submitting = false;
  String? _error;
  BookingLocationFix? _confirmedLocation;

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
          _confirmedLocation ??
          await (widget.locationProvider ??
                  BookingLocationResolver(initialFix: widget.initialLocation))
              .resolve();
      await widget.controller.create(
        serviceCategoryId: widget.category.id,
        description: _details.text,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (mounted) Navigator.of(context).pop(true);
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textOnSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Clear details help the right professional prepare before they accept.',
                      style: TextStyle(color: AppColors.textOnSurfaceSecondary),
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
      labelStyle: const TextStyle(
        color: AppColors.textOnSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onPressed: () => _addSuggestion(label),
    );
  }

  Future<void> _chooseLocationOnMap() async {
    final selected = await showModalBottomSheet<BookingLocationFix>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ServiceLocationPicker(initialLocation: widget.initialLocation),
    );
    if (selected != null && mounted) {
      setState(() {
        _confirmedLocation = selected;
        _error = null;
      });
    }
  }
}

class _ServiceLocationPicker extends StatefulWidget {
  const _ServiceLocationPicker({this.initialLocation});

  final BookingLocationFix? initialLocation;

  @override
  State<_ServiceLocationPicker> createState() => _ServiceLocationPickerState();
}

class _ServiceLocationPickerState extends State<_ServiceLocationPicker> {
  late LatLng _selected = widget.initialLocation == null
      ? const LatLng(20.5937, 78.9629)
      : LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm service location',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Tap your home or service address on the map. This pin is used only to match your provider.',
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label:
                'Service location map. Tap to place the service address pin.',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 320,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _selected,
                    initialZoom: widget.initialLocation == null ? 5 : 15,
                    onTap: (_, point) => setState(() => _selected = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fixnow.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selected,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 42,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FixPrimaryButton(
            label: 'Use this service location',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(
              BookingLocationFix(
                latitude: _selected.latitude,
                longitude: _selected.longitude,
                accuracyMeters: 0,
                timestamp: DateTime.now(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
