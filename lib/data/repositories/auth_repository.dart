import '../../core/config/env_config.dart';
import '../models/app_user.dart';
import '../services/local_store.dart';
import '../services/remote_api.dart';

/// Handles registration, sign in, sign out and profile storage.
///
/// In demo mode (no Supabase configured) credentials are not verified and the
/// profile is kept locally. Once [EnvConfig.hasSupabase] is true, all auth
/// flows go through the Supabase project owned by the app operator.
class AuthRepository {
  AuthRepository({
    RemoteApi? remote,
  }) : _remote = remote ?? RemoteApi.instance;

  final RemoteApi _remote;

  bool get isDemoMode => EnvConfig.isDemoMode;

  /// Returns the current signed-in user, or null when signed out.
  Future<AppUser?> currentUser() async {
    if (isDemoMode) {
      return LocalStore.getUser();
    }
    if (!_remote.isReady) return null;
    return _remote.currentUser();
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (isDemoMode) {
      await LocalStore.saveUser(
        AppUser(
          id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          displayName: displayName,
        ),
      );
      return;
    }
    await _remote.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    final user = _remote.currentUser();
    if (user != null) {
      await _remote.updateProfile(user);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (isDemoMode) {
      final existing = await LocalStore.getUser();
      if (existing != null) {
        // Demo mode: keep the locally registered identity and its progress.
        return;
      }
      await LocalStore.saveUser(
        AppUser(
          id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          displayName: email.split('@').first,
        ),
      );
      return;
    }
    await _remote.signInWithEmail(email: email, password: password);
  }

  Future<void> signOut() async {
    if (isDemoMode) {
      await LocalStore.saveUser(null);
      return;
    }
    await _remote.signOut();
  }

  Future<void> updateProfile(AppUser user) async {
    if (isDemoMode) {
      await LocalStore.saveUser(user);
      return;
    }
    await _remote.updateProfile(user);
  }
}
