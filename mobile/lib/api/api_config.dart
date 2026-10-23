import 'package:fixnow_mobile/config/app_environment.dart';

class ApiConfig {
  ApiConfig._();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static Uri baseUriFor(AppEnvironment environment) {
    final configured = _configuredBaseUrl.trim();
    final value = configured.isNotEmpty
        ? configured
        : (environment == AppEnvironment.development
            ? 'http://127.0.0.1:8080/api/v1/'
            : 'https://fixnow-lwys.onrender.com/api/v1/');
    final uri = Uri.parse(value);

    if (!uri.hasScheme || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
      throw StateError(
        'API_BASE_URL must be an absolute URL without a query or fragment.',
      );
    }
    if (environment != AppEnvironment.development && uri.scheme != 'https') {
      throw StateError('API_BASE_URL must use HTTPS outside development.');
    }

    var path = uri.path;
    if (!path.endsWith('/')) {
      path = '$path/';
    }
    if (!path.contains('/api/v1/')) {
      path = '${path}api/v1/';
    }
    path = path.replaceAll(RegExp(r'/+'), '/');

    return uri.replace(path: path);
  }
}
