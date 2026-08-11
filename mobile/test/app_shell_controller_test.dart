import 'package:fixnow_mobile/app/app_shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notifies only when the selected destination changes', () {
    final controller = AppShellController();
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.selectDestination(0, destinationCount: 4);
    controller.selectDestination(2, destinationCount: 4);

    expect(controller.selectedIndex, 2);
    expect(notifications, 1);
  });

  test('rejects destinations outside the shell boundary', () {
    final controller = AppShellController();

    expect(
      () => controller.selectDestination(4, destinationCount: 4),
      throwsRangeError,
    );
  });
}
