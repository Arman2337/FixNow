import 'package:flutter/foundation.dart';

class AppShellController extends ChangeNotifier {
  AppShellController({int initialIndex = 0}) : _selectedIndex = initialIndex;

  int _selectedIndex;

  int get selectedIndex => _selectedIndex;

  void selectDestination(int index, {required int destinationCount}) {
    if (index < 0 || index >= destinationCount) {
      throw RangeError.range(index, 0, destinationCount - 1, 'index');
    }
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }
}
