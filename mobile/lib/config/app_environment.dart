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
    defaultValue: 'FixNow Technologies Private Limited',
  );
  static const companyGstin = String.fromEnvironment(
    'COMPANY_GSTIN',
    defaultValue: '24AAACF1234F1Z5',
  );
  static const companySac = String.fromEnvironment(
    'COMPANY_SAC',
    defaultValue: '9987',
  );
  static const companyAddress = String.fromEnvironment(
    'COMPANY_ADDRESS',
    defaultValue: 'Level 4, Commerce House, SG Highway, Ahmedabad, Gujarat - 380054',
  );
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@fixnow.app',
  );
  static const invoiceVerifyUrl = String.fromEnvironment(
    'INVOICE_VERIFY_URL',
    defaultValue: 'https://fixnow.app/verify/invoice',
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
