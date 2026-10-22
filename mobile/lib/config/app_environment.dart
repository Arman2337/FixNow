enum AppEnvironment {
  development,
  staging,
  production;

  static const _configuredName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const emergencyHotline = String.fromEnvironment('EMERGENCY_HOTLINE');

  static const companyName = String.fromEnvironment(
    'COMPANY_NAME',
    defaultValue: 'FixNow',
  );
  static const companyGstin = String.fromEnvironment('COMPANY_GSTIN');
  static const companySac = String.fromEnvironment('COMPANY_SAC');
  static const companyAddress = String.fromEnvironment('COMPANY_ADDRESS');
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@fixnow.app',
  );
  static const invoiceVerifyUrl = String.fromEnvironment('INVOICE_VERIFY_URL');

  static AppEnvironment get current => fromName(_configuredName);

  /// Missing registration configuration must never become a fabricated tax ID.
  static bool get hasTaxRegistration =>
      RegExp(
        r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$',
      ).hasMatch(companyGstin) &&
      companyName.trim().isNotEmpty &&
      companyAddress.trim().isNotEmpty &&
      companySac.trim().isNotEmpty;

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
