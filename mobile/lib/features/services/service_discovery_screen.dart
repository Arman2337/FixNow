import 'dart:convert';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/design_system/fix_motion.dart';
import 'package:fixnow_mobile/features/location/location_consent_card.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/location/booking_location.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:fixnow_mobile/features/ai/ai_recommendation_repository.dart';
import 'package:fixnow_mobile/features/ai/ai_recommendation_screen.dart';

class ServiceDiscoveryScreen extends StatefulWidget {
  const ServiceDiscoveryScreen({
    required this.controller,
    required this.locationController,
    this.bookingsController,
    this.onCategorySelected,
    this.aiRepository,
    super.key,
  });
  final ServiceDiscoveryController controller;
  final LocationConsentController locationController;
  final BookingController? bookingsController;
  final void Function(ServiceCategory, BookingLocationFix?)? onCategorySelected;
  final AiRecommendationRepository? aiRepository;

  @override
  State<ServiceDiscoveryScreen> createState() => _ServiceDiscoveryScreenState();
}

class _ServiceDiscoveryScreenState extends State<ServiceDiscoveryScreen> {
  String? _locationName;
  BookingLocationFix? _bookingLocation;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
    widget.locationController.addListener(_onLocationStateChanged);
    _onLocationStateChanged();
  }

  @override
  void dispose() {
    widget.locationController.removeListener(_onLocationStateChanged);
    super.dispose();
  }

  void _onLocationStateChanged() {
    if (widget.locationController.state == LocationPermissionState.granted &&
        _locationName == null) {
      _fetchLocationName();
    }
  }

  Future<void> _fetchLocationName() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 5),
                maximumAge: Duration(minutes: 5),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 5),
              ),
      );
      _bookingLocation = BookingLocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
      if (mounted) {
        setState(() => _locationName = 'Location found');
      }

      if (kIsWeb) {
        // Geocoding package doesn't support web by default without a web plugin.
        // We fallback to a generic message if it fails on web.
        try {
          final placemarks = await Geocoding()
              .placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 3));
          if (placemarks.isNotEmpty) {
            _updateLocationName(placemarks.first);
            return;
          }
        } catch (_) {
          try {
            final uri = Uri.parse(
              'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${position.latitude}&longitude=${position.longitude}&localityLanguage=en',
            );
            final response = await http
                .get(uri)
                .timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final city = data['city'] ?? data['locality'];
              final state = data['principalSubdivision'] ?? data['countryName'];
              if (mounted &&
                  city != null &&
                  state != null &&
                  city.toString().isNotEmpty) {
                setState(() {
                  _locationName = '$city, $state';
                });
                return;
              }
            }
          } catch (e) {
            debugPrint('Web geocoding fallback failed: $e');
          }
          if (mounted) {
            setState(() {
              _locationName = 'Location Found';
            });
          }
        }
      } else {
        final placemarks = await Geocoding()
            .placemarkFromCoordinates(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 3));
        if (placemarks.isNotEmpty) {
          _updateLocationName(placemarks.first);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch/geocode location: $e');
    }
  }

  void _updateLocationName(Placemark place) {
    final city =
        place.locality ??
        place.subAdministrativeArea ??
        place.administrativeArea;
    final state = place.administrativeArea ?? place.country;
    if (mounted && city != null && state != null) {
      setState(() {
        _locationName = '$city, $state';
      });
    }
  }

  void _handleQuickService(String slug, String name) {
    if (widget.controller.categories.isNotEmpty) {
      final match = widget.controller.categories
          .where(
            (c) =>
                c.slug.toLowerCase() == slug.toLowerCase() ||
                c.name.toLowerCase().contains(name.toLowerCase()),
          )
          .firstOrNull;
      if (match != null && widget.onCategorySelected != null) {
        _selectCategory(match);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name service is currently unavailable.')),
      );
    }
  }

  void _showEmergencyContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: AppColors.emergency),
            SizedBox(width: 8),
            Text('Emergency Support', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FixNow 24/7 Emergency Dispatch is available for urgent safety hazards.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Helpline: +91 800 349 6691\nDispatched in average 12 minutes.',
              style: TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connecting to 24/7 Emergency Dispatch...'),
                ),
              );
            },
            child: const Text('Call Dispatch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final isOfflineOrError =
          widget.controller.status == DiscoveryStatus.offline ||
          widget.controller.status == DiscoveryStatus.error ||
          widget.controller.status == DiscoveryStatus.empty;

      return RefreshIndicator(
        onRefresh: widget.controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            _buildCustomerHeader(context),
            const SizedBox(height: AppSpacing.lg),

            if (isOfflineOrError) ...[
              ..._content(context),
              const SizedBox(height: AppSpacing.xl),
              LocationConsentCard(controller: widget.locationController),
            ] else ...[
              FixEmergencyBanner(onCallNow: _showEmergencyContactDialog),
              const SizedBox(height: AppSpacing.md),

              FixAiPromptCard(
                onTap: _openAi,
              ),
              const SizedBox(height: AppSpacing.xl),

              _buildQuickServicesSection(context),
              const SizedBox(height: AppSpacing.xl),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Popular services',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  Text(
                    'Verified categories',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ..._content(context),

              const SizedBox(height: AppSpacing.xxl),
              _buildTrustAndSafetySection(context),
              const SizedBox(height: AppSpacing.lg),
              const FixCard(
                tone: FixCardTone.elevated,
                semanticLabel: 'Verified professional matching',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.verified),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trusted local professionals',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Requests are offered only to eligible providers. Assignment happens after acceptance.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LocationConsentCard(controller: widget.locationController),
              const SizedBox(height: AppSpacing.lg),
              _buildActiveBookingCard(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        ),
      );
    },
  );

  Widget _buildActiveBookingCard() {
    if (widget.bookingsController == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: widget.bookingsController!,
      builder: (context, _) {
        final active = widget.bookingsController!.bookings
            .where(
              (b) => const {
                'REQUESTED',
                'ASSIGNED',
                'EN_ROUTE',
                'IN_PROGRESS',
              }.contains(b.status),
            )
            .firstOrNull;
        if (active == null) return const SizedBox.shrink();

        String title = '';
        IconData icon = Icons.info_outline;
        Color color = AppColors.primary;

        switch (active.status) {
          case 'REQUESTED':
            title = 'Finding a professional...';
            icon = Icons.search_rounded;
            break;
          case 'ASSIGNED':
            title = 'Professional accepted your request';
            icon = Icons.check_circle_outline;
            break;
          case 'EN_ROUTE':
            title = 'Your professional is on the way';
            icon = Icons.directions_car_rounded;
            break;
          case 'IN_PROGRESS':
            title = 'Service is in progress';
            icon = Icons.build_rounded;
            break;
        }

        return FixCard(
          tone: FixCardTone.elevated,
          semanticLabel: 'Active booking status: $title',
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      active.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerHeader(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.locationController,
      builder: (context, _) {
        final isGranted =
            widget.locationController.state == LocationPermissionState.granted;
        final locationText = isGranted
            ? (_locationName ?? 'Locating...')
            : 'Enable Location';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      if (!isGranted) {
                        widget.locationController.request();
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.accentGold,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accentGold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.accentGold,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.cream,
                      ),
                      children: const [
                        TextSpan(text: 'Right help. '),
                        TextSpan(
                          text: 'Right now.',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const FixAvatar(name: 'Arman', size: 44, isVerified: true),
          ],
        );
      },
    );
  }

  Widget _buildQuickServicesSection(BuildContext context) {
    final quickItems = [
      (Icons.plumbing_rounded, 'Plumber', 'plumbing'),
      (Icons.electrical_services_rounded, 'Electrician', 'electrical'),
      (Icons.kitchen_rounded, 'Appliance Pro', 'appliance-repair'),
      (Icons.ac_unit_rounded, 'AC Expert', 'hvac'),
      (Icons.carpenter_rounded, 'Carpenter', 'carpentry'),
      (Icons.cleaning_services_rounded, 'Cleaning', 'cleaning'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FixSectionHeader(
          title: 'Quick Services',
          subtitle: 'Choose a service to match nearby pros in minutes',
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.05,
          ),
          itemCount: quickItems.length,
          itemBuilder: (context, index) {
            final item = quickItems[index];
            return FixFadeSlideIn(
              delay: AppMotion.staggerStep * index,
              child: InkWell(
                onTap: () => _handleQuickService(item.$3, item.$2),
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Icon(
                          item.$1,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: AppColors.textOnLightPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrustAndSafetySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FixSectionHeader(
          title: 'Why FixNow?',
          subtitle: 'Guaranteed quality with 30-day service protection',
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildTrustCard(
                icon: Icons.verified_user_rounded,
                title: 'Verified Pros',
                description: '100% background checked professionals',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildTrustCard(
                icon: Icons.currency_rupee_rounded,
                title: 'Fixed Pricing',
                description:
                    'Transparent upfront estimates with no hidden fees',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildTrustCard(
                icon: Icons.shield_rounded,
                title: '30-Day Protection',
                description: 'Complete warranty on eligible completed work',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildTrustCard(
                icon: Icons.lock_clock_rounded,
                title: 'OTP Verified Work',
                description: 'Work begins only after safety code confirmation',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentGold, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textOnLightPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textOnLightSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context) =>
      switch (widget.controller.status) {
        DiscoveryStatus.initial || DiscoveryStatus.loading => const [
          _DiscoverySkeleton(),
        ],
        DiscoveryStatus.empty => [
          _DiscoveryMessage(
            title: 'No services available',
            message: 'Services will appear here when they become available.',
            onRetry: widget.controller.load,
          ),
        ],
        DiscoveryStatus.offline => [
          _DiscoveryMessage(
            title: 'You are offline',
            message: 'Check your connection, then try again.',
            onRetry: widget.controller.load,
          ),
        ],
        DiscoveryStatus.error => [
          _DiscoveryMessage(
            title: 'Services unavailable',
            message: 'We could not load services. Try again.',
            onRetry: widget.controller.load,
          ),
        ],
        DiscoveryStatus.ready => [
          _CategoryList(
            categories: widget.controller.categories,
            onSelected: _selectCategory,
          ),
        ],
      };

  void _selectCategory(ServiceCategory category) =>
      widget.onCategorySelected?.call(category, _bookingLocation);

  Future<void> _openAi() async {
    if (widget.aiRepository == null) return;
    final category = await Navigator.of(context).push<ServiceCategory>(
      MaterialPageRoute(
        builder: (_) => AiRecommendationScreen(
          repository: widget.aiRepository!,
          categories: widget.controller.categories,
        ),
      ),
    );
    if (category != null && mounted) _selectCategory(category);
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.onSelected});
  final List<ServiceCategory> categories;
  final ValueChanged<ServiceCategory>? onSelected;

  @override
  Widget build(BuildContext context) => FixCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < categories.length; index += 1) ...[
          _CategoryRow(
            category: categories[index],
            onTap: onSelected == null
                ? null
                : () => onSelected!(categories[index]),
          ),
          if (index < categories.length - 1)
            const Divider(height: 1, indent: 64),
        ],
      ],
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});
  final ServiceCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: '${category.name} service category',
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.inputBorder,
                ),
                child: Icon(
                  _categoryIcon(category.iconName),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (category.description case final description?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                category.pricing?.displayLabel ?? 'Price on request',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: category.pricing == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );

  static IconData _categoryIcon(String? value) => switch (value) {
    'plumbing' => Icons.plumbing_outlined,
    'electrical_services' => Icons.electrical_services_outlined,
    'ac_unit' => Icons.ac_unit_outlined,
    'key' => Icons.key_outlined,
    _ => Icons.home_repair_service_outlined,
  };
}

/// Loading placeholder for the services list. A single shimmer sweeps across a
/// stack of bars shaped like the real category rows, so the wait reads as
/// "content is coming" rather than a bare spinner.
class _DiscoverySkeleton extends StatelessWidget {
  const _DiscoverySkeleton();

  static Widget _bar(double width, double height, {double radius = 6}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading services',
    container: true,
    child: ExcludeSemantics(
      child: FixShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 5; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    _bar(44, 44, radius: AppRadius.medium),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(double.infinity, 14),
                          const SizedBox(height: AppSpacing.xs),
                          _bar(160, 12),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _bar(56, 12),
                  ],
                ),
              ),
              if (i < 4)
                const Divider(height: 1, color: AppColors.borderDefault),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DiscoveryMessage extends StatelessWidget {
  const _DiscoveryMessage({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FixCard(
    semanticLabel: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(message),
        const SizedBox(height: AppSpacing.lg),
        FixButton(
          label: 'Try again',
          onPressed: onRetry,
          variant: FixButtonVariant.secondary,
        ),
      ],
    ),
  );
}
