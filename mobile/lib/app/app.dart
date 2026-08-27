import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fixnow_mobile/app/app_shell.dart';
import 'package:fixnow_mobile/app/app_navigation.dart';
import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/api/api_config.dart';
import 'package:fixnow_mobile/auth/auth_api.dart';
import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/auth_session.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:fixnow_mobile/auth/auth_screen.dart';
import 'package:fixnow_mobile/auth/role_selection_screen.dart';
import 'package:fixnow_mobile/auth/welcome_screen.dart';
import 'package:fixnow_mobile/auth/verification_screen.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/bookings/booking.dart';
import 'package:fixnow_mobile/features/bookings/booking_detail_screen.dart';
import 'package:fixnow_mobile/features/bookings/booking_repository.dart';
import 'package:fixnow_mobile/features/bookings/customer_bookings_screen.dart';
import 'package:fixnow_mobile/features/bookings/recurring_schedule.dart';
import 'package:fixnow_mobile/features/bookings/service_request_screen.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_controller.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_repository.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_screen.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';
import 'package:fixnow_mobile/features/services/sub_service_catalog_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_earnings_repository.dart';
import 'package:fixnow_mobile/features/provider/provider_earnings_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_home_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_jobs_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_onboarding_screen.dart';
import 'package:fixnow_mobile/features/support/complaint_list_screen.dart';
import 'package:fixnow_mobile/features/support/submit_complaint_screen.dart';
import 'package:fixnow_mobile/features/provider/provider_repository.dart';
import 'package:fixnow_mobile/features/support/complaints_controller.dart';
import 'package:fixnow_mobile/features/support/complaints_repository.dart';
import 'package:fixnow_mobile/features/support/customer_help_screen.dart';
import 'package:fixnow_mobile/features/ai/ai_recommendation_repository.dart';
import 'package:fixnow_mobile/features/ai/price_estimate_repository.dart';
import 'package:fixnow_mobile/features/ai/problem_analysis_repository.dart';
import 'package:fixnow_mobile/features/emergency/emergency_repository.dart';
import 'package:fixnow_mobile/features/payments/invoice_repository.dart';
import 'package:fixnow_mobile/features/payments/invoice_screen.dart';
import 'package:fixnow_mobile/features/payments/local_payment_repository.dart';

import 'package:fixnow_mobile/features/realtime/realtime_client.dart';
import 'package:fixnow_mobile/notifications/push_api.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:fixnow_mobile/features/chat/chat_repository.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_controller.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_screen.dart';
import 'package:fixnow_mobile/features/tracking/booking_tracking_source.dart';

class FixNowApp extends StatefulWidget {
  const FixNowApp({
    required this.environment,
    this.apiTransport,
    this.sessionStore,
    this.locationGateway,
    super.key,
  });

  final AppEnvironment environment;
  final ApiTransport? apiTransport;
  final AuthSessionStore? sessionStore;
  final LocationPermissionGateway? locationGateway;

  @override
  State<FixNowApp> createState() => _FixNowAppState();
}

class _FixNowAppState extends State<FixNowApp> with WidgetsBindingObserver {
  late final ApiTransport _api;
  late final AuthController _auth;
  late final CustomerProfileController _profile;
  late final ServiceDiscoveryController _discovery;
  late final ApiServiceCategoryRepository _categoryRepository;
  late final LocationConsentController _location;
  late final BookingController _bookings;
  late final SchedulesController _schedules;
  late final ProviderController _provider;
  late final ComplaintsController _complaints;
  late final PushEnrollmentController _push;
  late final ChatRepository _chatRepository;
  late final CallRepository _callRepository;
  final Map<String, BookingTrackingController> _trackingControllers = {};
  /// FN-062: app-wide messenger so foreground pushes can surface as banners
  /// from any screen.
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final FirebasePushGateway _pushGateway = FirebasePushGateway();
  StreamSubscription<ForegroundPushMessage>? _foregroundPushSub;
  _AuthEntryStep _authEntryStep = _AuthEntryStep.welcome;
  bool _registrationIntent = false;
  AccountRole _selectedRole = AccountRole.customer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _foregroundPushSub = bindForegroundPushBanner(
      source: _pushGateway,
      messengerKey: _messengerKey,
    );
  }

  void _initializeData() {
    final api =
        widget.apiTransport ??
        ApiClient(baseUri: ApiConfig.baseUriFor(widget.environment));
    _api = api;
    _auth = AuthController(
      api: AuthApi(api),
      store: widget.sessionStore ??
          (kIsWeb ? WebAuthSessionStore() : SecureAuthSessionStore()),
    );
    _profile = CustomerProfileController(
      ApiCustomerProfileRepository(
        api: api,
        accessToken: _auth.validAccessToken,
      ),
    );
    _discovery = ServiceDiscoveryController(ApiServiceCategoryRepository(api));
    _categoryRepository = ApiServiceCategoryRepository(api);
    _location = LocationConsentController(
      widget.locationGateway ?? const PlatformLocationPermissionGateway(),
    );
    _bookings = BookingController(
      BookingRepository(api: api, accessToken: _auth.validAccessToken),
      realtime: _createRealtimeClient(),
    );
    _schedules = SchedulesController(_bookings.repository);
    _provider = ProviderController(
      ProviderRepository(api: api, accessToken: _auth.validAccessToken),
      realtime: _createRealtimeClient(),
    );
    _complaints = ComplaintsController(
      ComplaintsRepository(api),
    );
    _push = PushEnrollmentController(
      api: PushApi(api, accessToken: _auth.validAccessToken),
      gateway: _pushGateway,
    );
    _chatRepository = HttpChatRepository(
      api: api,
      accessToken: _auth.validAccessToken,
    );
    _callRepository = HttpCallRepository(
      api: api,
      accessToken: _auth.validAccessToken,
    );
    _auth.restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_foregroundPushSub?.cancel());
    _auth.dispose();
    _profile.dispose();
    _discovery.dispose();
    _location.dispose();
    _bookings.dispose();
    _schedules.dispose();
    _provider.dispose();
    _complaints.dispose();
    _push.dispose();
    for (final controller in _trackingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FixNow',
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) {
          if (_auth.status == AuthStatus.initial ||
              _auth.status == AuthStatus.loading && _auth.session == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Restoring session',
                ),
              ),
            );
          }
          if (_auth.status == AuthStatus.verificationRequired) {
            return VerificationScreen(controller: _auth);
          }
          if (!_auth.isAuthenticated) {
            return switch (_authEntryStep) {
              _AuthEntryStep.welcome => WelcomeScreen(
                onGetStarted: () => _selectIntent(true),
                onSignIn: () => _selectIntent(false),
              ),
              _AuthEntryStep.role => RoleSelectionScreen(
                isRegistration: _registrationIntent,
                onBack: () =>
                    setState(() => _authEntryStep = _AuthEntryStep.welcome),
                onContinue: (role) => setState(() {
                  _selectedRole = role;
                  _authEntryStep = _AuthEntryStep.form;
                }),
              ),
              _AuthEntryStep.form => AuthScreen(
                controller: _auth,
                role: _selectedRole,
                initialRegister: _registrationIntent,
                onBack: () =>
                    setState(() => _authEntryStep = _AuthEntryStep.role),
              ),
            };
          }
          if (_auth.session?.role == AccountRole.providerApplicant) {
            if (_provider.state == ProviderLoadState.loading &&
                _provider.application == null) {
              _provider.load(verified: false);
            }
            return ProviderOnboardingScreen(
              controller: _provider,
              pushController: _push,
              onSupportCases: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplaintListScreen(
                        controller: _complaints,
                      ),
                    ),
                  );
                },
                onSignOut: _signOut,
            );
          }
          if (_auth.session?.role == AccountRole.verifiedProvider) {
            if (_provider.state == ProviderLoadState.loading &&
                _provider.application == null) {
              _provider.load(verified: true);
            }
            return AppShell(
              role: AppShellRole.provider,
              providerHome: ProviderHomeScreen(
                controller: _provider,
                loadAcceptTime: () async {
                  try {
                    return await _provider.repository.acceptTime();
                  } catch (_) {
                    // An unavailable signal is hidden, never faked.
                    return null;
                  }
                },
                onViewEarnings: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderEarningsScreen(
                      repository: ProviderEarningsRepository(
                        _api,
                        accessToken: _auth.validAccessToken,
                      ),
                    ),
                  ),
                ),
              ),
              providerJobs: ProviderJobsScreen(
                controller: _provider,
                showHistory: false,
              ),
              providerHistory: ProviderJobsScreen(
                controller: _provider,
                showHistory: true,
              ),
              providerProfile: ProviderOnboardingScreen(
                controller: _provider,
                pushController: _push,
                onSupportCases: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplaintListScreen(
                        controller: _complaints,
                      ),
                    ),
                  );
                },
                onSignOut: _signOut,
              ),
            );
          }
          unawaited(_bookings.startRealtime());
          return AppShell(
            customerHome: ServiceDiscoveryScreen(
              controller: _discovery,
              locationController: _location,
              bookingsController: _bookings,
              emergencyRepository: EmergencyRepository(_api, accessToken: _auth.validAccessToken),
              onCategorySelected: (category, location) async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => SubServiceCatalogScreen(
                      category: category,
                      initialLocation: location,
                      onProceedToBooking: (updatedCategory, description, priceMinor, loc) async {
                        final reqCreated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ServiceRequestScreen(
                              category: updatedCategory,
                              controller: _bookings,
                              initialLocation: loc,
                              initialDescription: description,
                              estimateRepository: PriceEstimateRepository(_api, accessToken: _auth.validAccessToken),
                            ),
                          ),
                        );
                        if (reqCreated == true && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                    ),
                  ),
                );
                if (created == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Request created. We are finding an eligible provider.',
                      ),
                    ),
                  );
                }
              },
              aiRepository: AiRecommendationRepository(_api, _auth.validAccessToken),
              problemAnalysisRepository: ProblemAnalysisRepository(
                _api,
                accessToken: _auth.validAccessToken,
              ),
            ),
            customerProfile: CustomerProfileScreen(
              controller: _profile,
              pushController: _push,
              onSupportCases: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ComplaintListScreen(
                        controller: _complaints,
                      ),
                    ),
                  );
                },
                onSignOut: _signOut,
            ),
            customerBookings: CustomerBookingsScreen(
              controller: _bookings,
              onBookingSelected: (booking) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => _bookingDestination(booking)),
              ),
              onBookAgain: (booking) => _openRebooking(context, booking),
              schedulesController: _schedules,
              onOccurrenceConfirmed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Visit booked. We are finding an eligible provider.'),
                  ),
                );
                unawaited(_bookings.load());
              },
            ),
            customerHelp: CustomerHelpScreen(
              controller: _complaints,
            ),
          );
        },
      ),
    );
  }

  /// FN-108 book-again: resolve the prior booking's category and open a
  /// prefilled request. Location is re-resolved under the normal consent and
  /// freshness policy; submission is an ordinary idempotent request creation.
  Future<void> _openRebooking(
    BuildContext context,
    CustomerBooking booking,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    List<ServiceCategory> categories;
    try {
      categories = await _categoryRepository.active();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'We could not load services. Check your connection and try again.',
          ),
        ),
      );
      return;
    }
    final category = categories
        .where((item) => item.id == booking.serviceCategoryId)
        .firstOrNull;
    if (!mounted) return;
    if (category == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'That service is no longer available to book. Choose one from Home.',
          ),
        ),
      );
      return;
    }
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ServiceRequestScreen(
          category: category,
          controller: _bookings,
          initialDescription: booking.description,
          estimateRepository: PriceEstimateRepository(_api, accessToken: _auth.validAccessToken),
        ),
      ),
    );
  }

  void _selectIntent(bool registration) => setState(() {
    _registrationIntent = registration;
    _authEntryStep = _AuthEntryStep.role;
  });

  Widget _bookingDestination(CustomerBooking booking) {
    return ListenableBuilder(
      listenable: _bookings,
      builder: (context, _) {
        final currentBooking = _bookings.bookings.firstWhere(
          (b) => b.id == booking.id,
          orElse: () => booking,
        );
        final active = {
          'ASSIGNED',
          'EN_ROUTE',
          'IN_PROGRESS',
        }.contains(currentBooking.status);
        if (!active) {
          return BookingDetailScreen(
            booking: currentBooking,
            onReportIssue: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubmitComplaintScreen(
                      controller: _complaints,
                      bookingId: currentBooking.id,
                      targetRole: 'PROVIDER',
                      targetId: null,
                    ),
                  ),
                );
              },
            onCancel: const {'REQUESTED', 'ASSIGNED'}.contains(currentBooking.status)
                ? (reason) => _bookings.cancel(currentBooking, reason)
                : null,
            reviewRepository: _bookings.repository,
            onBookAgain: currentBooking.status == 'COMPLETED'
                ? () => _openRebooking(context, currentBooking)
                : null,
            onViewInvoice: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InvoiceScreen(
                  repository: InvoiceRepository(
                    _api,
                    accessToken: _auth.validAccessToken,
                  ),
                  localPaymentRepository: LocalPaymentRepository(
                    _api,
                    accessToken: _auth.validAccessToken,
                  ),
                  bookingId: currentBooking.id,
                ),
              ),
            ),
          );
        }
        final tracking = _trackingControllers.putIfAbsent(
          currentBooking.id,
          () => BookingTrackingController(
            bookingId: currentBooking.id,
            source: ApiBookingTrackingSource(
              api: _api,
              accessToken: _auth.validAccessToken,
            ),
            realtime: _createRealtimeClient(),
          ),
        );
        return BookingTrackingScreen(
          controller: tracking,
          chatRepository: _chatRepository,
          callRepository: _callRepository,
        );
      },
    );
  }

  RealtimeClient? _createRealtimeClient() {
    if (widget.apiTransport != null) return null;
    final uri = ApiConfig.baseUriFor(widget.environment);
    return RealtimeClient(
      uri: realtimeUriFromApi(uri),
      accessToken: _auth.validAccessToken,
    );
  }

  Future<void> _signOut() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() => _authEntryStep = _AuthEntryStep.welcome);
  }
}

enum _AuthEntryStep { welcome, role, form }
