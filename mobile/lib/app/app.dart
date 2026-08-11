import 'package:flutter/material.dart';
import 'package:fixnow_mobile/app/app_shell.dart';
import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/api/api_config.dart';
import 'package:fixnow_mobile/auth/auth_api.dart';
import 'package:fixnow_mobile/auth/auth_controller.dart';
import 'package:fixnow_mobile/auth/auth_session_store.dart';
import 'package:fixnow_mobile/config/app_environment.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_controller.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_repository.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_screen.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:fixnow_mobile/features/services/service_discovery_screen.dart';

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

class _FixNowAppState extends State<FixNowApp> {
  late final AuthController _auth;
  late final CustomerProfileController _profile;
  late final ServiceDiscoveryController _discovery;
  late final LocationConsentController _location;

  @override
  void initState() {
    super.initState();
    final api =
        widget.apiTransport ??
        ApiClient(baseUri: ApiConfig.baseUriFor(widget.environment));
    _auth = AuthController(
      api: AuthApi(api),
      store: widget.sessionStore ?? SecureAuthSessionStore(),
    );
    _profile = CustomerProfileController(
      ApiCustomerProfileRepository(
        api: api,
        accessToken: _auth.validAccessToken,
      ),
    );
    _discovery = ServiceDiscoveryController(ApiServiceCategoryRepository(api));
    _location = LocationConsentController(
      widget.locationGateway ?? const PlatformLocationPermissionGateway(),
    );
    _auth.restore();
  }

  @override
  void dispose() {
    _auth.dispose();
    _profile.dispose();
    _discovery.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          widget.environment != AppEnvironment.production,
      title: 'FixNow',
      theme: AppTheme.light,
      home: AppShell(
        customerHome: ServiceDiscoveryScreen(
          controller: _discovery,
          locationController: _location,
        ),
        customerProfile: CustomerProfileScreen(controller: _profile),
      ),
    );
  }
}
