import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_theme.dart';
import 'package:fixnow_mobile/features/profile/customer_profile.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_controller.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_repository.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads and saves only the display name', (tester) async {
    final repository = FakeProfileRepository(
      const CustomerProfile(displayName: 'Asha'),
    );
    final controller = CustomerProfileController(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CustomerProfileScreen(controller: controller)),
      ),
    );
    await tester.pump();

    expect(
      find.text('Only your display name is collected here.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('location is not part of your profile'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), '  Asha Patel  ');
    await tester.tap(find.text('Save profile'));
    await tester.pump();

    expect(repository.updatedWith, 'Asha Patel');
    expect(find.text('Profile saved'), findsOneWidget);
  });

  testWidgets('shows offline state with a retry action', (tester) async {
    final repository = FakeProfileRepository(
      const CustomerProfile(displayName: null),
      error: const ApiException(ApiFailureKind.offline, 'offline'),
    );
    final controller = CustomerProfileController(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CustomerProfileScreen(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('You are offline'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('rejects an empty display name accessibly', (tester) async {
    final controller = CustomerProfileController(
      FakeProfileRepository(const CustomerProfile(displayName: 'Asha')),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CustomerProfileScreen(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Save profile'));
    await tester.pump();

    expect(find.text('Enter a display name.'), findsOneWidget);
  });
}

class FakeProfileRepository implements CustomerProfileRepository {
  FakeProfileRepository(this.profile, {this.error});
  CustomerProfile profile;
  final ApiException? error;
  String? updatedWith;

  @override
  Future<CustomerProfile> read() async {
    if (error case final value?) throw value;
    return profile;
  }

  @override
  Future<CustomerProfile> update(String displayName) async {
    updatedWith = displayName;
    profile = CustomerProfile(displayName: displayName);
    return profile;
  }
}
