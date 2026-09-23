import 'dart:async';
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
import 'package:fixnow_mobile/features/services/service_image_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:fixnow_mobile/features/ai/ai_recommendation_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_controller.dart';
import 'package:fixnow_mobile/features/ai/problem_diagnosis_screen.dart';
import 'package:fixnow_mobile/design_system/fix_notification_bell.dart';
import 'package:fixnow_mobile/design_system/fix_address_selector.dart';
import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:fixnow_mobile/features/location/service_location_picker_sheet.dart';
import 'package:fixnow_mobile/features/notifications/notification_center_screen.dart';
import 'package:fixnow_mobile/features/notifications/notification_controller.dart';
import 'package:fixnow_mobile/features/notifications/notification_model.dart';
import 'package:fixnow_mobile/features/services/fix_universal_search_bar.dart';

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
    this.onInvoiceSelected,
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
  final void Function(InAppNotification notification)? onInvoiceSelected;

  @override
  State<ServiceDiscoveryScreen> createState() => _ServiceDiscoveryScreenState();
}

class _ServiceDiscoveryScreenState extends State<ServiceDiscoveryScreen> {
  String? _locationName;
  BookingLocationFix? _bookingLocation;
  bool _isLoadingLocation = false;
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
    if (widget.locationController.state == LocationPermissionState.unknown) {
      widget.locationController.check();
    } else {
      _onLocationStateChanged();
    }
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

  Future<void> _fetchLocationName({bool forceRefresh = false}) async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);
    try {
      if (!kIsWeb && !forceRefresh && _bookingLocation == null) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null && mounted) {
            _bookingLocation = BookingLocationFix(
              latitude: last.latitude,
              longitude: last.longitude,
              accuracyMeters: last.accuracy,
              timestamp: last.timestamp,
            );
            unawaited(_reverseGeocode(last.latitude, last.longitude));
            setState(() {});
          }
        } catch (_) {}
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? WebSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 10),
                maximumAge: const Duration(minutes: 5),
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
      );
      if (mounted) {
        setState(() {
          _bookingLocation = BookingLocationFix(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
            timestamp: position.timestamp,
          );
        });
        await _reverseGeocode(position.latitude, position.longitude);
      }
    } catch (e) {
      // No fake fallback: an unfixed location stays null so the booking flow
      // asks for a real fix or an explicit map pick instead of silently
      // booking at a demo address.
      debugPrint('Failed to fetch/geocode location: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    if (!kIsWeb) {
      try {
        final placemarks = await Geocoding()
            .placemarkFromCoordinates(lat, lng)
            .timeout(const Duration(seconds: 3));
        if (placemarks.isNotEmpty) {
          _updateLocationName(placemarks.first);
          return;
        }
      } catch (_) {
        // Geocoder service unavailable; fall through to HTTP geocoding
      }
    }

    try {
      final uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final city = data['city'] ?? data['locality'];
        final state = data['principalSubdivision'] ?? data['countryName'];
        if (mounted && city != null && city.toString().trim().isNotEmpty) {
          setState(() {
            _locationName = (state != null && state.toString().trim().isNotEmpty)
                ? '${city.toString().trim()}, ${state.toString().trim()}'
                : city.toString().trim();
          });
        }
      }
    } catch (e) {
      debugPrint('HTTP geocoding fallback failed: $e');
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

  void _showLocationOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CustomerLocationOptionsSheet(
        currentLocationName: _locationName,
        isLoading: _isLoadingLocation,
        onRefreshLiveLocation: () {
          Navigator.of(sheetContext).pop();
          _fetchLocationName(forceRefresh: true);
        },
        onSelectSavedAddress: (addr) {
          Navigator.of(sheetContext).pop();
          setState(() {
            _bookingLocation = BookingLocationFix(
              latitude: addr.latitude,
              longitude: addr.longitude,
              accuracyMeters: 10,
              timestamp: DateTime.now(),
            );
            _locationName = addr.formattedSnippet.isNotEmpty
                ? addr.formattedSnippet
                : addr.city;
          });
        },
        onPickOnMap: () async {
          Navigator.of(sheetContext).pop();
          final picked = await ServiceLocationPickerSheet.show(
            context,
            initialLocation: _bookingLocation,
          );
          if (picked != null && mounted) {
            setState(() {
              _bookingLocation = picked;
              _locationName =
                  'Custom Pin (${picked.latitude.toStringAsFixed(3)}, ${picked.longitude.toStringAsFixed(3)})';
            });
            unawaited(_reverseGeocode(picked.latitude, picked.longitude));
          }
        },
        onAddNewAddress: () async {
          Navigator.of(sheetContext).pop();
          final newAddr = await AddEditAddressModalSheet.show(context);
          if (newAddr != null && mounted) {
            setState(() {
              _bookingLocation = BookingLocationFix(
                latitude: newAddr.latitude,
                longitude: newAddr.longitude,
                accuracyMeters: 10,
                timestamp: DateTime.now(),
              );
              _locationName = newAddr.formattedSnippet.isNotEmpty
                  ? newAddr.formattedSnippet
                  : newAddr.city;
            });
          }
        },
      ),
    );
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
        color: AppColors.accentGold,
        backgroundColor: AppColors.surfaceElevated,
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
              onFilterChanged: (filter) =>
                  setState(() => _filterOption = filter),
              onAiDiagnose: _openDiagnose,
            ),
            const SizedBox(height: AppSpacing.md),

            if (_isSearching) ...[
              _buildSearchResultsSection(context),
              const SizedBox(height: AppSpacing.xl),
            ] else if (isOfflineOrError) ...[
              ..._content(context),
              const SizedBox(height: AppSpacing.xl),
              LocationConsentCard(controller: widget.locationController),
            ] else ...[
              _buildActiveBookingCard(),
              const SizedBox(height: AppSpacing.md),

              FixEmergencyBanner(
                onCallNow: _openEmergencyFlow,
                subtitle: 'Priority dispatch for home safety hazards.',
              ),
              const SizedBox(height: AppSpacing.md),

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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verified categories',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ..._content(context),

              const SizedBox(height: AppSpacing.xxl),
              _buildCommunityFavouritesSection(context),
              const SizedBox(height: AppSpacing.xl),

              _buildTrustAndSafetySection(context),
              const SizedBox(height: AppSpacing.lg),
              _buildCustomerGuaranteeSection(context),
              const SizedBox(height: AppSpacing.lg),
              LocationConsentCard(controller: widget.locationController),
              const SizedBox(height: AppSpacing.xl),
            ],
          ],
        ),
      );
    },
  );

  Widget _buildSearchResultsSection(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final allSubServices = widget.controller.allSubServices;
    final categories = widget.controller.categories;

    // Filter sub-services
    var filtered = allSubServices.where((item) {
      final matchesQuery =
          query.isEmpty ||
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
        filtered.sort(
          (a, b) =>
              (b.badge != null ? 1 : 0).compareTo(a.badge != null ? 1 : 0),
        );
        break;
      case SearchSortOption.relevance:
        break;
    }

    if (filtered.isEmpty) {
      const suggestions = [
        'Tap Repair',
        'Ceiling Fan',
        'AC Service',
        'Drain Cleaning',
        'Switchboard',
      ];
      return FixCard(
        tone: FixCardTone.elevated,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No services found for "${_searchController.text.trim()}"',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.cream,
                fontSize: 16,
              ),
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
                  label: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.cream,
                    ),
                  ),
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
              child: const Text(
                'Reset',
                style: TextStyle(color: AppColors.accentGold),
              ),
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
              name:
                  item.categorySlug[0].toUpperCase() +
                  item.categorySlug.substring(1),
              slug: item.categorySlug,
            ),
          );

          return StaggeredListReveal(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FixSpringBounce(
                onTap: () =>
                    widget.onCategorySelected?.call(cat, _bookingLocation),
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
                          border: Border.all(
                            color: AppColors.borderGold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppColors.accentGold,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGold.withValues(
                                        alpha: 0.2,
                                      ),
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
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
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => widget.onCategorySelected
                                      ?.call(cat, _bookingLocation),
                                  child: const Text(
                                    'View & Book',
                                    style: TextStyle(fontSize: 12),
                                  ),
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
        String etaText = 'Live GPS Dispatch';
        IconData icon = Icons.info_outline;

        switch (active.status) {
          case 'REQUESTED':
            title = 'Matching Verified Pro...';
            etaText = 'Broadcasting nearby';
            icon = Icons.radar_rounded;
            break;
          case 'ASSIGNED':
            title = 'Professional Assigned';
            etaText = 'Preparing toolkit';
            icon = Icons.check_circle_outline;
            break;
          case 'EN_ROUTE':
            title = 'On the way';
            etaText = 'Arriving in ~6 mins';
            icon = Icons.two_wheeler_rounded;
            break;
          case 'IN_PROGRESS':
            title = 'Service In Progress';
            etaText = 'Safe session active';
            icon = Icons.build_rounded;
            break;
        }

        final category = widget.controller.categories
            .where((c) => c.id == active.serviceCategoryId)
            .firstOrNull;
        final categoryTitle = (category?.name ?? 'Home Service').toUpperCase();

        return Semantics(
          label: 'Active booking status: $title',
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF131F2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'JOB IN PROGRESS • $categoryTitle',
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
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
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            etaText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: const Color(0xFF34D399),
                            size: 22,
                          ),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.two_wheeler_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Active • ${active.status.replaceAll('_', ' ')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${active.id.length > 6 ? active.id.substring(0, 6).toUpperCase() : active.id.toUpperCase()}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active.description.isNotEmpty
                                ? active.description
                                : 'Service Booking #${active.id.length > 8 ? active.id.substring(0, 8) : active.id}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text(
                          'SECURITY',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'OTP GATED',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (widget.onBookingSelected != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => widget.onBookingSelected!(active.id),
                        icon: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunityFavouritesSection(BuildContext context) {
    final categories = widget.controller.categories;
    if (categories.isEmpty) return const SizedBox.shrink();

    final items = categories.take(6).map((cat) {
      final price = cat.pricing != null
          ? cat.pricing!.displayLabel
          : 'On inspection';
      final ratingStr = cat.rating != null
          ? '${cat.rating!.toStringAsFixed(1)} ★ (${cat.reviewCount})'
          : 'Verified Pro';
      return (
        '${cat.name} Package',
        cat.description ?? '${cat.name} inspection, maintenance & repair.',
        price,
        ServiceImageResolver.resolveImage(cat.slug) ?? '',
        ratingStr,
        cat.slug,
        cat.name,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community Favourites',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Top-rated local service packages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Top Rated',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 280,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 270,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDefault),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (item.$4.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: Image.asset(
                          item.$4,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 13,
                                            color: Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            item.$5,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 11,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            '30-Day',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.$1,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.$3,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton(
                                  onPressed: () =>
                                      _handleQuickService(item.$6, item.$7),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Book Express',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerGuaranteeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'FIXNOW CUSTOMER GUARANTEE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '100% Insured',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildGuaranteePillar(
                  icon: Icons.lock_rounded,
                  title: 'Escrow Pay',
                  subtitle: 'Pay after work approval',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildGuaranteePillar(
                  icon: Icons.badge_rounded,
                  title: 'Police Verified',
                  subtitle: '7-point screening',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildGuaranteePillar(
                  icon: Icons.receipt_long_rounded,
                  title: 'MRP Parts',
                  subtitle: 'Zero mark-up on spares',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteePillar({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.locationController,
      builder: (context, _) {
        final isGranted =
            widget.locationController.state == LocationPermissionState.granted;
        final locationText = isGranted
            ? (_isLoadingLocation && _locationName == null
                ? 'Detecting live location...'
                : (_locationName ?? 'Current Location'))
            : 'Enable Location';
        final onlineCount = widget.controller.categories.fold<int>(
          0,
          (sum, c) => sum + c.onlineProCount,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stitch Brand Header Bar
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuBq3W54yVgIIYzS2ZmyZZ0d9kwFAN6ICfuhZt7xwzFvvtpyeMbbct9nXWFyX6ptnBKyMW12g8HEm89mm4UmVE44PrFuYKwUIb3SRYCHXq6Kv8tUUv752LSORLe_9kWLBzwm99CMXx7tdvhIVHJJ7TmMjQ0d0QncryYSbDns4E39pUp7H_O9pED5oar2w3k3xSsY_XM0-6M2n5Rytv5n6ety7Afuy6O3MEGapgQX1Qgy5iqdYxMhAfBqp19_6hNc40YqTw',
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'FixNow',
                              style: FixNowTypography.headlineMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryEmerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Explore Home',
                        style: FixNowTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.notificationController != null) ...[
                  FixNotificationBellIcon(
                    controller: widget.notificationController!,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationCenterScreen(
                            controller: widget.notificationController!,
                            onOpenBooking: widget.onBookingSelected,
                            onOpenInvoice: widget.onInvoiceSelected,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Stitch Location Selector Card & Live Online Micro-Counter
            InkWell(
              onTap: () {
                if (!isGranted) {
                  widget.locationController.request();
                } else {
                  _showLocationOptionsSheet();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    if (isGranted)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                _bookingLocation?.latitude ??
                                    SavedAddressRepository
                                        .instance
                                        .defaultAddress
                                        ?.latitude ??
                                    20.5937,
                                _bookingLocation?.longitude ??
                                    SavedAddressRepository
                                        .instance
                                        .defaultAddress
                                        ?.longitude ??
                                    78.9629,
                              ),
                              initialZoom: _bookingLocation != null ? 14.0 : 5.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.stitch.fixnow',
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isGranted)
                      Positioned.fill(
                        child: Container(color: const Color(0xBB0B131F)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? Colors.transparent
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Row(
                        children: [
                          if (_isLoadingLocation)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryEmerald,
                              ),
                            )
                          else
                            Icon(
                              Icons.near_me_rounded,
                              color: isGranted
                                  ? AppColors.primaryFixed
                                  : AppColors.primary,
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        locationText,
                                        style: FixNowTypography.label.copyWith(
                                          color: isGranted
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: isGranted
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                Text(
                                  isGranted
                                      ? 'Verified Service Grid'
                                      : 'Tap to enable matching',
                                  style: FixNowTypography.labelSmall.copyWith(
                                    color: isGranted
                                        ? Colors.white70
                                        : AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (onlineCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$onlineCount Pros Online',
                                    style: const TextStyle(
                                      color: AppColors.onPrimaryFixed,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
            final imageUrl = ServiceImageResolver.resolveImage(item.$3);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imageUrl != null)
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.card),
                            ),
                            child: Image.asset(imageUrl, fit: BoxFit.cover),
                          ),
                        )
                      else
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium,
                                ),
                              ),
                              child: Icon(
                                item.$1,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Text(
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
                          ),
                        ),
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
        const FixSectionHeader(title: 'In safe hands', subtitle: ''),
        const SizedBox(height: AppSpacing.md),
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
              _buildBulletPoint(
                icon: Icons.verified_user_rounded,
                title: 'Vetted professionals',
                description: 'Only the top 5% of experts make the cut.',
              ),
              const SizedBox(height: AppSpacing.md),
              _buildBulletPoint(
                icon: Icons.currency_rupee_rounded,
                title: 'Transparent pricing',
                description: 'No hidden fees, ever.',
              ),
              const SizedBox(height: AppSpacing.md),
              _buildBulletPoint(
                icon: Icons.security_rounded,
                title: 'Secure payments',
                description: 'Your data is protected and payments are safe.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const FixSectionHeader(title: 'Guaranteed Satisfaction', subtitle: ''),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '30-Day Service Guarantee',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'If you\'re not satisfied with the work, we will make it right at no extra cost.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        const FixSectionHeader(title: 'We are here for you', subtitle: ''),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '+91 1800-FIX-NOW',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Call Now',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.email_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'support@fixnow.com',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Email Us',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context) =>
      switch (widget.controller.status) {
        DiscoveryStatus.initial ||
        DiscoveryStatus.loading => const [_DiscoverySkeleton()],
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 600;
      final crossAxisCount = isWide ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) => FixFadeSlideIn(
          delay: AppMotion.staggerStep * index,
          child: _card(categories[index]),
        ),
      );
    },
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
      isGridTile: true,
      icon: _categoryIcon(category.iconName),
      imageUrl: ServiceImageResolver.resolveImage(category.slug),
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
      semanticLabel:
          '${category.name} service category'
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

class _CustomerLocationOptionsSheet extends StatelessWidget {
  const _CustomerLocationOptionsSheet({
    required this.currentLocationName,
    required this.isLoading,
    required this.onRefreshLiveLocation,
    required this.onSelectSavedAddress,
    required this.onPickOnMap,
    required this.onAddNewAddress,
  });

  final String? currentLocationName;
  final bool isLoading;
  final VoidCallback onRefreshLiveLocation;
  final ValueChanged<SavedAddress> onSelectSavedAddress;
  final VoidCallback onPickOnMap;
  final VoidCallback onAddNewAddress;

  @override
  Widget build(BuildContext context) {
    final addresses = SavedAddressRepository.instance.addresses;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Service Location',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Option 1: Use Current Live Location (GPS)
              InkWell(
                onTap: isLoading ? null : onRefreshLiveLocation,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryEmerald,
                          shape: BoxShape.circle,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Current Live Location',
                              style: FixNowTypography.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentLocationName != null
                                  ? 'Current: $currentLocationName'
                                  : 'Detects real device GPS coordinates',
                              style: FixNowTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Option 2: Choose on Map
              InkWell(
                onTap: onPickOnMap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose on Map',
                              style: FixNowTypography.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Place an exact pin on the map',
                              style: FixNowTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              if (addresses.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Addresses',
                      style: FixNowTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    TextButton(
                      onPressed: onAddNewAddress,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '+ Add New',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final addr = addresses[index];
                      return InkWell(
                        onTap: () => onSelectSavedAddress(addr),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                addr.icon,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      addr.labelText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      addr.formattedSnippet,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (addr.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryEmerald.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      color: AppColors.primaryEmerald,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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
