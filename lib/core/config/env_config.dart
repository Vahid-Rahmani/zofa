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

  /// Optional custom translation endpoint for the dynamic dictionary bridge.
  ///
  /// When set, the app POSTs `{"word": ..., "source": ..., "target": ...}` to
  /// this URL and expects a JSON object with a `translation` field (plus
  /// optional `part_of_speech`, `gender`, `definition`, `example`,
  /// `example_translation`, `alternates`). Point it at a self-hosted LLM
  /// proxy to replace the free Google/Wiktionary provider.
  static const String translationEndpoint = String.fromEnvironment(
    'ZOVA_TRANSLATION_ENDPOINT',
    defaultValue: '',
  );

  /// Optional bearer token sent to [translationEndpoint].
  static const String translationApiKey = String.fromEnvironment(
    'ZOVA_TRANSLATION_API_KEY',
    defaultValue: '',
  );

  /// AI tutor API key (Google Gemini by default; any OpenAI-compatible
  /// provider when [aiProvider] says so).
  ///
  /// Never hard-code a key in the source tree. Provide it at build/run time:
  ///
  /// ```sh
  /// flutter run --dart-define-from-file=.env
  /// ```
  ///
  /// with a git-ignored `.env` file containing
  /// `ZOVA_AI_API_KEY=...`. When the key is empty the AI tutor is disabled
  /// and the app stays fully offline, falling back to its static data.
  static const String aiApiKey = String.fromEnvironment(
    'ZOVA_AI_API_KEY',
    defaultValue: '',
  );

  /// AI provider: `gemini` (default) or `openai` (any OpenAI-compatible
  /// `/chat/completions` endpoint). When empty the key prefix decides.
  static const String aiProvider = String.fromEnvironment(
    'ZOVA_AI_PROVIDER',
    defaultValue: '',
  );

  /// Optional base URL override. Defaults to
  /// `https://generativelanguage.googleapis.com/v1beta` for Gemini and
  /// `https://api.openai.com/v1` for OpenAI-compatible providers.
  static const String aiBaseUrl = String.fromEnvironment(
    'ZOVA_AI_BASE_URL',
    defaultValue: '',
  );

  /// Optional model override. Defaults to `gemini-2.0-flash` for Gemini and
  /// `gpt-4o-mini` for OpenAI-compatible providers.
  static const String aiModel = String.fromEnvironment(
    'ZOVA_AI_MODEL',
    defaultValue: '',
  );

  static String get appName => _appName;

  /// Whether a real Supabase backend is configured.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether Stripe is configured.
  static bool get hasStripe => stripePublishableKey.isNotEmpty;

  /// Whether a custom translation bridge endpoint is configured.
  static bool get hasTranslationEndpoint => translationEndpoint.isNotEmpty;

  /// Whether an AI tutor API key is configured.
  static bool get hasAi => aiApiKey.isNotEmpty;

  /// The app uses a local demo backend when no remote services are set up.
  static bool get isDemoMode => !hasSupabase;
}
