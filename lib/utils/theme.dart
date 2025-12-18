// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'custom_color.dart';

class Themes {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  _saveThemeToBox(bool isDarkMode) => _box.write(_key, isDarkMode);

  bool _loadThemeFromBox() => _box.read(_key) ?? false;

  ThemeMode get theme => _loadThemeFromBox() ? ThemeMode.dark : ThemeMode.light;

  void switchTheme() {
    Get.changeThemeMode(_loadThemeFromBox() ? ThemeMode.light : ThemeMode.dark);
    _saveThemeToBox(!_loadThemeFromBox());
  }



  static final light = ThemeData.light().copyWith(
    primaryColor: CustomColor.primaryColor,
    scaffoldBackgroundColor: CustomColor.bgColorLightMode,
    brightness: Brightness.light,
    appBarTheme:  const AppBarTheme(backgroundColor: CustomColor.primaryColor),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.black,
          displayColor: CustomColor.black.withOpacity( 0.6),
        ),
  );
  static final dark = ThemeData.dark().copyWith(
    primaryColor: CustomColor.primaryColor,
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: Colors.transparent),
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(backgroundColor: CustomColor.appBarColor),
    scaffoldBackgroundColor: CustomColor.bgColorDarkMode,
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: CustomColor.white.withOpacity( 0.6),
        ),
  );
}
