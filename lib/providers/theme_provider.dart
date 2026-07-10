import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const _boxName = 'settings';
  static const _key = 'isDarkMode';

  late Box _box;
  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _isDark = _box.get(_key, defaultValue: false) as bool;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    await _box.put(_key, _isDark);
    notifyListeners();
  }
}
