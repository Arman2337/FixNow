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
import 'package:fixnow_mobile/design_system/fix_motion_suite.dart';
import 'package:fixnow_mobile/features/emergency/emergency_confirm_screen.dart';
import 'package:fixnow_mobile/features/emergency/emergency_repository.dart';
import 'package:fixnow_mobile/design_system/fix_service_card.dart';
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
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_controller.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_screen.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/features/notifications/notification_center_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/services/fix_universal_search_bar.dart';
import 'package:fixnow_mobile/features/services/sub_service_item.dart';

class ServiceDiscoveryScreen extends StatefulWidget {
  const ServiceDiscoveryScreen({
    required this.controller,
    required this.locationController,
    this.bookingsController,
    this.onCategorySelected,
    this.aiRepository,
    this.problemAnalysisRepository,
    this.emergencyRepository,
    this.notificationController,
    this.onBookingSelected,
    super.key,
  });
  final ServiceDiscoveryController controller;
  final LocationConsentController locationController;
  final BookingController? bookingsController;
  final void Function(ServiceCategory, BookingLocationFix?)? onCategorySelected;
  final AiRecommendationRepository? aiRepository;
  final ProblemAnalysisRepository? problemAnalysisRepository;
  final EmergencyRepository? emergencyRepository;
  final NotificationController? notificationController;
  final void Function(String bookingId)? onBookingSelected;

  @override
  State<ServiceDiscoveryScreen> createState() => _ServiceDiscoveryScreenState();
}

class _ServiceDiscoveryScreenState extends State<ServiceDiscoveryScreen> {
  String? _locationName;
  BookingLocationFix? _bookingLocation;
  final _searchController = TextEditingController();
  SearchSortOption _sortOption = SearchSortOption.relevance;
  SearchFilterOption _filterOption = SearchFilterOption.all;

  bool get _isSearching =>
      _searchController.text.trim().isNotEmpty ||
      _filterOption != SearchFilterOption.all ||
      _sortOption != SearchSortOption.relevance;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
    widget.locationController.addListener(_onLocationStateChanged);
    _onLocationStateChanged();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  /// FN-064: entry point for the deliberate two-step emergency journey when
  /// active emergency categories exist; otherwise honest guidance only.
  void _openEmergencyFlow() {
    final emergencies = widget.controller.categories
        .where((category) => category.isEmergency)
        .toList();
    final repository = widget.emergencyRepository;
    if (emergencies.isEmpty || repository == null) {
      _showEmergencyGuidanceDialog();
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => EmergencyConfirmScreen(
              categories: emergencies,
              repository: repository,
            ),
          ),
        )
        .then((_) => widget.controller.load());
  }

  void _showEmergencyGuidanceDialog() {
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
              'FixNow priority dispatch alerts nearby verified professionals '
              'for home safety hazards. It is not an emergency service.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'If anyone is in danger, call your local emergency number first.',
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
            const SizedBox(height: AppSpacing.md),

            // FN-130: Universal Live Search, Filter & Price Sort Bar
            FixUniversalSearchBar(
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              onClear: () => setState(() {
                _searchController.clear();
                _filterOption = SearchFilterOption.all;
                _sortOption = SearchSortOption.relevance;
              }),
              activeSort: _sortOption,
              onSortChanged: (sort) => setState(() => _sortOption = sort),
              activeFilter: _filterOption,
              onFilterChanged: (filter) => setState(() => _filterOption = filter),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (_isSearching) ...[
              _buildSearchResultsSection(context),
              const SizedBox(height: AppSpacing.xl),
            ] else if (isOfflineOrError) ...[
              ..._content(context),
              const SizedBox(height: AppSpacing.xl),
              LocationConsentCard(controller: widget.locationController),
            ] else ...[
              FixEmergencyBanner(
                onCallNow: _openEmergencyFlow,
                subtitle: 'Priority dispatch for home safety hazards.',
              ),
              const SizedBox(height: AppSpacing.md),

              FixAiPromptCard(
                onTap: _openAi,
              ),
              if (widget.problemAnalysisRepository != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildDiagnoseCard(),
              ],
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

  Widget _buildSearchResultsSection(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final allSubServices = SubServiceCatalog.getAllSubServices();
    final categories = widget.controller.categories;

    // Filter sub-services
    var filtered = allSubServices.where((item) {
      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.categorySlug.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      // Filter options
      switch (_filterOption) {
        case SearchFilterOption.under300:
          if (item.priceMinor > 30000) return false;
          break;
        case SearchFilterOption.under500:
          if (item.priceMinor > 50000) return false;
          break;
        case SearchFilterOption.emergency:
          final cat = categories.firstWhere(
            (c) => c.slug == item.categorySlug || c.id == item.categorySlug,
            orElse: () => ServiceCategory(id: '', name: '', slug: ''),
          );
          if (!cat.isEmergency && item.durationMinutes > 45) return false;
          break;
        case SearchFilterOption.all:
          break;
      }
      return true;
    }).toList();

    // Sort
    switch (_sortOption) {
      case SearchSortOption.priceLowHigh:
        filtered.sort((a, b) => a.priceMinor.compareTo(b.priceMinor));
        break;
      case SearchSortOption.priceHighLow:
        filtered.sort((a, b) => b.priceMinor.compareTo(a.priceMinor));
        break;
      case SearchSortOption.fastest:
        filtered.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
        break;
      case SearchSortOption.popular:
        filtered.sort((a, b) => (b.badge != null ? 1 : 0).compareTo(a.badge != null ? 1 : 0));
        break;
      case SearchSortOption.relevance:
        break;
    }

    if (filtered.isEmpty) {
      const suggestions = ['Tap Repair', 'Ceiling Fan', 'AC Service', 'Drain Cleaning', 'Switchboard'];
      return FixCard(
        tone: FixCardTone.elevated,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No services found for "${_searchController.text.trim()}"',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.cream, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Try popular home maintenance requests:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) {
                return ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.cream)),
                  backgroundColor: AppColors.backgroundSecondary,
                  side: const BorderSide(color: AppColors.borderDefault),
                  onPressed: () {
                    setState(() {
                      _searchController.text = s;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Search Results (${filtered.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.cream,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _filterOption = SearchFilterOption.all;
                  _sortOption = SearchSortOption.relevance;
                });
              },
              child: const Text('Reset', style: TextStyle(color: AppColors.accentGold)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...filtered.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final cat = categories.firstWhere(
            (c) => c.slug == item.categorySlug || c.id == item.categorySlug,
            orElse: () => ServiceCategory(
              id: item.categorySlug,
              name: item.categorySlug[0].toUpperCase() + item.categorySlug.substring(1),
              slug: item.categorySlug,
            ),
          );

          return StaggeredListReveal(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FixSpringBounce(
                onTap: () => widget.onCategorySelected?.call(cat, _bookingLocation),
                child: FixCard(
                  tone: FixCardTone.elevated,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
                        ),
                        child: Icon(item.icon, color: AppColors.accentGold, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    cat.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (item.badge != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGold.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.badge!,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accentGold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.cream,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.formattedPrice,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.accentGold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${item.durationMinutes} mins',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => widget.onCategorySelected?.call(cat, _bookingLocation),
                                  child: const Text('View & Book', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.notificationController != null) ...[
                  FixNotificationBellIcon(
                    controller: widget.notificationController!,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationCenterScreen(
                            controller: widget.notificationController!,
                            onOpenBooking: widget.onBookingSelected,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                const FixAvatar(name: 'Arman', size: 44, isVerified: true),
              ],
            ),
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
              child: FixSpringBounce(
                onTap: () => _handleQuickService(item.$3, item.$2),
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

  Widget _buildDiagnoseCard() => Semantics(
    button: true,
    label: 'Diagnose your problem. Add a photo or describe it by voice.',
    child: InkWell(
      onTap: _openDiagnose,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagnose your problem',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Add a photo or describe it by voice',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.mic_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openDiagnose() async {
    if (widget.problemAnalysisRepository == null) return;
    final category = await Navigator.of(context).push<ServiceCategory>(
      MaterialPageRoute(
        builder: (_) => ProblemDiagnosisScreen(
          controller: ProblemDiagnosisController(
            widget.problemAnalysisRepository!,
          ),
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
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < categories.length; index += 1) ...[
        if (index > 0) const SizedBox(height: AppSpacing.md),
        // A gentle staggered reveal, echoing the quick-services grid above.
        FixFadeSlideIn(
          delay: AppMotion.staggerStep * index,
          child: _card(categories[index]),
        ),
      ],
    ],
  );

  /// Presents a real category as a service card. Every bound signal is real
  /// platform data: name, description, icon, the admin-published price, the
  /// backend `isEmergency` flag, and — only when there is data behind them —
  /// the live availability strip and the rating. With no verified pros, nobody
  /// online, and no reviews (a fresh deployment) the strip and stars simply
  /// don't render, so the card never implies a count or rating we can't stand
  /// behind. Avatar faces are never shown: we have real counts, not real
  /// identities, so [FixServiceCard.showProStack] stays off.
  Widget _card(ServiceCategory category) {
    final action = onSelected == null ? null : () => onSelected!(category);
    final (num? amount, String currency) = _priceFor(category.pricing);
    final online = category.onlineProCount;
    final verified = category.verifiedProCount;
    final reviewCount = category.reviewCount > 0 ? category.reviewCount : null;

    final availabilityLabel = online > 0
        ? ', $online pros available now'
        : verified > 0
            ? ', $verified verified pros'
            : '';
    final ratingLabel = category.rating != null
        ? ', rated ${category.rating!.toStringAsFixed(1)} out of 5'
        : '';

    return FixServiceCard(
      name: category.name,
      description: category.description,
      descriptionMaxLines: 2,
      icon: _categoryIcon(category.iconName),
      badgeLabel: category.isEmergency ? 'Emergency' : null,
      // Show the strip only when real data backs it: pros online now, or a
      // verified-pro count to fall back to. Otherwise it stays hidden.
      showLiveStrip: online > 0 || verified > 0,
      prosAvailable: online,
      verifiedProsCount: verified,
      // We know real counts, not real pro identities — never show sample faces.
      showProStack: false,
      rating: category.rating,
      reviewCount: reviewCount,
      priceFrom: amount,
      priceCurrency: currency,
      priceNote: 'upfront · no hidden fees',
      semanticLabel: '${category.name} service category'
          '${category.isEmergency ? ', emergency service' : ''}'
          '$availabilityLabel$ratingLabel',
      onTap: action,
      onPrimaryAction: action,
    );
  }

  /// Resolves a display amount + currency symbol from published pricing. INR
  /// minor units (paise) collapse to rupees; other currencies pass their minor
  /// amount through until the pricing model widens. Null pricing → no price.
  static (num?, String) _priceFor(ServiceCategoryPricing? pricing) {
    if (pricing == null) return (null, '₹');
    if (pricing.currency == 'INR') return (pricing.amountMinor / 100, '₹');
    return (pricing.amountMinor, pricing.currency);
  }

  /// Maps a category's backend `iconName` to a Material glyph. Covers every
  /// value the seed migration ships. Two are deliberate stand-ins for glyphs
  /// not bundled in this Flutter build: locksmith uses an outline padlock, and
  /// pest control uses a shield (home-protection) rather than a bug.
  static IconData _categoryIcon(String? value) => switch (value) {
    'plumbing' => Icons.plumbing_rounded,
    'electrical_services' => Icons.electrical_services_rounded,
    'hvac' => Icons.ac_unit_rounded,
    'home_repair_service' => Icons.kitchen_rounded,
    'lock' => Icons.lock_outline,
    'handyman' => Icons.handyman_rounded,
    'cleaning_services' => Icons.cleaning_services_rounded,
    'pest_control' => Icons.shield_rounded,
    'emergency' => Icons.emergency_rounded,
    'carpenter' => Icons.carpenter_rounded,
    _ => Icons.home_repair_service_rounded,
  };
}

/// Loading placeholder for the services list. A single shimmer sweeps across a
/// short stack of card-shaped placeholders that mirror the real
/// [FixServiceCard]s — icon tile, title, price, and CTA — so the wait reads as
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

  /// One placeholder card, shaped like a real [FixServiceCard]: a tile + title
  /// block above a divider, then a price block beside a button.
  static Widget _card() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _bar(54, 54, radius: AppRadius.medium),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(150, 16),
                      const SizedBox(height: AppSpacing.sm),
                      _bar(double.infinity, 12),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _bar(26, 26, radius: AppRadius.pill),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.borderDefault),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(88, 22),
                      const SizedBox(height: AppSpacing.xs),
                      _bar(120, 10),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _bar(120, 46, radius: AppRadius.medium),
              ],
            ),
          ],
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
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              _card(),
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
