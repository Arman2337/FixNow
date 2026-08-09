enum AppEnvironment {
  development,
  staging,
  production;

  static const _configuredName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get current => fromName(_configuredName);

  static AppEnvironment fromName(String name) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == name,
      orElse: () => throw ArgumentError.value(
        name,
        'APP_ENV',
        'must be development, staging, or production',
      ),
    );
  }
}
