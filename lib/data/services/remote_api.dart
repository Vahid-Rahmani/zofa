import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env_config.dart';
import '../models/app_user.dart';
import '../models/user_progress.dart';

/// Thin wrapper around the Supabase client.
///
/// Supabase replaces the third-party Firebase stack of the reference app.
/// It provides both authentication (email/password) and the Postgres-backed
/// profile store, all under the app owner's own Supabase account.
class RemoteApi {
  RemoteApi._();

  static final RemoteApi instance = RemoteApi._();

  SupabaseClient? _client;

  bool get isReady => _client != null;

  SupabaseClient get _supabase {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase is not configured. Add ZOVA_SUPABASE_URL and '
        'ZOVA_SUPABASE_ANON_KEY via --dart-define.',
      );
    }
    return client;
  }

  /// Initialises the client once. No-op in demo mode.
  Future<void> init() async {
    if (!EnvConfig.hasSupabase) return;
    if (_client != null) return;
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  bool get isSignedIn =>
      isReady && _supabase.auth.currentSession != null;

  /// The user's access token, used to authenticate edge function calls.
  String? get accessToken =>
      isReady ? _supabase.auth.currentSession?.accessToken : null;

  AppUser? currentUser() {
    if (!isReady) return null;
    final session = _supabase.auth.currentSession;
    if (session == null) return null;
    return AppUser(
      id: session.user.id,
      email: session.user.email ?? '',
      displayName: session.user.userMetadata?['display_name'] as String?,
      learnedLanguage: (session.user.userMetadata?['learned_language']
              as String?) ??
          'English',
      nativeLanguage:
          (session.user.userMetadata?['native_language'] as String?) ??
              'German',
      level: (session.user.userMetadata?['level'] as String?) ?? 'beginner',
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'display_name': displayName ?? '',
        'learned_language': 'English',
        'native_language': 'German',
        'level': 'beginner',
      },
    );
    final user = response.user;
    if (user == null) {
      throw Exception('Registration failed. Please try again.');
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) {
      throw Exception('Sign in failed. Please try again.');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> updateProfile(AppUser user) async {
    await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          'display_name': user.displayName,
          'learned_language': user.learnedLanguage,
          'native_language': user.nativeLanguage,
          'level': user.level,
        },
      ),
    );
    final id = currentUser()?.id ?? user.id;
    if (id.isEmpty) return;
    await _supabase.from('profiles').upsert(user.toJson());
  }

  Future<UserProgress?> fetchProgress(String userId) async {
    final rows = await _supabase
        .from('profiles')
        .select('progress')
        .eq('id', userId)
        .maybeSingle();
    final raw = rows?['progress'];
    if (raw == null) return null;
    return UserProgress.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  Future<void> upsertProgress(String userId, UserProgress progress) async {
    await _supabase.from('profiles').upsert({
      'id': userId,
      'progress': progress.toJson(),
    });
  }
}
