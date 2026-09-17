import 'package:fixnow_mobile/features/profile/customer_profile.dart';
void main() {
  final json = {
    'displayName': 'Test',
    'stats': {
      'completedJobs': 5,
      'cashbackMinor': 0,
      'activeWarranties': 1
    }
  };
  final p = CustomerProfile.fromJson(json);
  print(p.displayName);
}
