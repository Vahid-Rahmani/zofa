import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/user_progress.dart';

/// Local persistence used by the demo backend.
///
/// Data is kept on-device in SharedPreferences. When a real Supabase project
/// is configured, the same values are mirrored to the remote profile store;
/// the local copy still works as an offline cache.
class LocalStore {
  LocalStore._();

  static const _kUser = 'zova.user';
  static const _kProgress = 'zova.progress';
  static const _kOnboarded = 'zova.onboarded';

  static Future<AppUser?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUser(AppUser? user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_kUser);
    } else {
      await prefs.setString(_kUser, jsonEncode(user.toJson()));
    }
  }

  static Future<UserProgress> getProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProgress);
    if (raw == null) return const UserProgress();
    try {
      return UserProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UserProgress();
    }
  }

  static Future<void> saveProgress(UserProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProgress, jsonEncode(progress.toJson()));
  }

  static Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboarded) ?? false;
  }

  static Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, value);
  }
}
