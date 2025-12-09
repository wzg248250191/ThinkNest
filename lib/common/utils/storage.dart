import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// kv离线存储
/// 为特定平台的持久化存储提供简单的数据包装（在 iOS 和 macOS 上使用 NSUserDefaults，在 Android 上使用 SharedPreferences 等）。
/// 数据可能会异步写入磁盘，并且无法保证在返回后会将写入的数据持久化到磁盘，因此此插件不得用于存储关键数据。
/// 支持的数据类型为 int 、 double 、 bool 、 String 和 List<String> 。
class Storage {
  // 单例写法
  static final Storage _instance = Storage._internal();
  factory Storage() => _instance;
  late final SharedPreferences _prefs;

  Storage._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<bool> setJson(String key, Object value) async {
    return await _prefs.setString(key, jsonEncode(value));
  }

  Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  Future<bool> setList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }

  String getString(String key) {
    return _prefs.getString(key) ?? '';
  }

  bool getBool(String key) {
    return _prefs.getBool(key) ?? false;
  }

  List<String> getList(String key) {
    return _prefs.getStringList(key) ?? [];
  }

  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }
}

