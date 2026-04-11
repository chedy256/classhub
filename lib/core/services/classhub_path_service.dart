import 'package:shared_preferences/shared_preferences.dart';

//stock the data even after closing the app:the chosen path,it allows storing
//read and write the data from physical disk so that's why we used async and await
class ClasshubPathService {
  //this class manages the root path for the app
  static const String _pathKey = 'classhub_root_path';

  ///pathkey:is a private(acessible only here),static:belong to this file only, constant used as the key for storing and retrieving the root path in SharedPreferences
  /// used to stock the path chosen ,recall it on any launch,and if not defines it returns the default path

  static Future<String> getPath() async {
    ///recover the path from shared preferences,if it dosen't exist return the default path
    final prefs = await SharedPreferences.getInstance();

    ///loading from the disk
    final path = prefs.getString(_pathKey) ?? '';
    //checks if the path has a value or null,then it's an empty string
    if (path.isEmpty) return '/storage/emulated/0';
    //if no path chosen return the default path
    return path;
  }

  /// Whether the user has explicitly chosen a path
  static Future<bool> hasCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_pathKey);
    return saved != null && saved.isNotEmpty;
  }

  /// saves users chosen path to shared preferences
  static Future<void> savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
  }

  /// delete the saved path,i used for when the user wants to reset the app or change the path
  static Future<void> clearPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
  }
}
//SharedPreferences read/write from disks,so it takes time,that's why we used async and await to avoid blocking the main thread while performing these operations. 
///await :waits for the result before moving to the the next operation