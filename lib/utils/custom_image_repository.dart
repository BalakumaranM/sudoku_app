import 'package:shared_preferences/shared_preferences.dart';

class CustomImageRepository {
  static const String _keyPrefix = 'custom_img_';
  static Future<void> saveCustomImage(int index, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$index', path);
  }
  static Future<List<String?>> loadCustomImages() async {
    final prefs = await SharedPreferences.getInstance();
    return List.generate(9, (i) => prefs.getString('$_keyPrefix$i'));
  }

  static Future<void> clearCustomImages() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < 9; i++) {
      await prefs.remove('$_keyPrefix$i');
    }
  }
}
