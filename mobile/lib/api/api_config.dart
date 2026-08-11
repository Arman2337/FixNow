import 'package:fixnow_mobile/config/app_environment.dart';

class ApiConfig {
  ApiConfig._();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static Uri baseUriFor(AppEnvironment environment) {
    final configured = _configuredBaseUrl.trim();
    final value = configured.isEmpty
        ? 'http://127.0.0.1:3000/api/v1/'
        : configured;
    final uri = Uri.parse(value);

    if (!uri.hasScheme || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
      throw StateError(
        'API_BASE_URL must be an absolute URL without a query or fragment.',
      );
    }
    if (environment != AppEnvironment.development && uri.scheme != 'https') {
      throw StateError('API_BASE_URL must use HTTPS outside development.');
    }

    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }
}
