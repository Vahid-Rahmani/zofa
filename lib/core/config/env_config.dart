/// Runtime configuration for zova.
///
/// Replace the placeholder values with your own credentials:
///
/// * [supabaseUrl] and [supabaseAnonKey] — from your Supabase project
///   (Dashboard > Settings > API).
/// * [stripePublishableKey] — from your Stripe account
///   (Dashboard > Developers > API keys). The *secret* key must never be
///   shipped in the app; it lives only in the Supabase Edge Function.
///
/// When the values are left empty, the app falls back to a fully local
/// demo backend so the UI can be explored without any server.
class EnvConfig {
  EnvConfig._();

  static const String _appName = 'zova';

  static const String supabaseUrl = String.fromEnvironment(
    'ZOVA_SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'ZOVA_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String stripePublishableKey = String.fromEnvironment(
    'ZOVA_STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// URL of the Supabase Edge Function that creates Stripe sessions.
  static const String stripeSessionFunctionUrl = String.fromEnvironment(
    'ZOVA_STRIPE_SESSION_FUNCTION_URL',
    defaultValue: '',
  );

  static String get appName => _appName;

  /// Whether a real Supabase backend is configured.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether Stripe is configured.
  static bool get hasStripe => stripePublishableKey.isNotEmpty;

  /// The app uses a local demo backend when no remote services are set up.
  static bool get isDemoMode => !hasSupabase;
}
