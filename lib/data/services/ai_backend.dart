import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/env_config.dart';

/// A single chat-completion request to an AI provider.
class AiChatRequest {
  const AiChatRequest({
    required this.system,
    required this.user,
    this.maxTokens,
  });

  /// The system prompt that steers the model (role, language, output format).
  final String system;

  /// The user message (the actual question or lookup).
  final String user;

  /// Cap on generated tokens, to bound cost and latency.
  final int? maxTokens;
}

/// A pluggable AI completion provider.
///
/// Implementations return `null` — never throw — when they cannot produce an
/// answer (network failure, rate limit, malformed response, ...) so the
/// [AiTutorService] can fall back to its local cache.
abstract class AiBackend {
  /// Returns the raw completion text for [request], or `null` on any failure.
  Future<String?> completeText(AiChatRequest request);
}

/// Returns the backend to use by default.
///
/// The provider is chosen from `ZOVA_AI_PROVIDER` (`gemini` or `openai`).
/// When it is not set, the key prefix decides: OpenAI-style keys (`sk-…`) use
/// the OpenAI-compatible endpoint, everything else (including the new Google
/// `AQ.` auth keys) uses the Gemini native endpoint. When no API key is
/// configured at all, an [UnconfiguredAiBackend] is returned so the app never
/// touches the network.
AiBackend buildDefaultAiBackend() {
  if (!EnvConfig.hasAi) return const UnconfiguredAiBackend();
  final provider = EnvConfig.aiProvider.trim().toLowerCase();
  if (provider == 'openai' || provider == 'openai-compatible') {
    return OpenAiCompatibleAiBackend();
  }
  if (provider == 'gemini' || provider == 'google') {
    return GeminiAiBackend();
  }
  if (EnvConfig.aiApiKey.startsWith('sk-')) {
    return OpenAiCompatibleAiBackend();
  }
  return GeminiAiBackend();
}

/// The default provider: Google Gemini's native `generateContent` endpoint.
///
/// The API key is read from `ZOVA_AI_API_KEY` and sent as the `key` query
/// parameter; the model defaults to `gemini-2.0-flash` and the base URL to
/// `https://generativelanguage.googleapis.com/v1beta`, both overridable via
/// `ZOVA_AI_MODEL` / `ZOVA_AI_BASE_URL`.
class GeminiAiBackend implements AiBackend {
  GeminiAiBackend({
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
    String? baseUrl,
    String? apiKey,
    String? model,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            (EnvConfig.aiBaseUrl.isEmpty
                ? 'https://generativelanguage.googleapis.com/v1beta'
                : EnvConfig.aiBaseUrl),
        _apiKey = apiKey ?? EnvConfig.aiApiKey,
        _model = model ??
            (EnvConfig.aiModel.isEmpty
                ? 'gemini-2.0-flash'
                : EnvConfig.aiModel);

  final http.Client _client;
  final Duration timeout;
  final String _baseUrl;
  final String _apiKey;
  final String _model;

  static const String _jsonMime = 'application/json';

  @override
  Future<String?> completeText(AiChatRequest request) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/models/$_model:generateContent?key=$_apiKey',
      );
      final response = await _client
          .post(
            uri,
            headers: {'content-type': _jsonMime},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': '${request.system}\n\n${request.user}'},
                  ],
                },
              ],
              'generationConfig': {
                'responseMimeType': _jsonMime,
                'temperature': 0.3,
                'maxOutputTokens': request.maxTokens ?? 1000,
              },
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return parseGenerateContent(response.body);
    } on Exception {
      return null;
    }
  }

  /// Extracts the completion text from a `generateContent` response body.
  static String? parseGenerateContent(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>? ?? const [];
      for (final raw in candidates) {
        final candidate = raw as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        if (content == null) continue;
        final parts = content['parts'] as List<dynamic>? ?? const [];
        final text = parts
            .map((part) =>
                (part as Map<String, dynamic>)['text'] as String? ?? '')
            .join()
            .trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    } on Exception {
      return null;
    }
  }
}

/// OpenAI-compatible chat completions provider (OpenAI, DeepSeek, Groq, any
/// proxy exposing `/chat/completions`).
///
/// The API key is sent as a `Bearer` token; the model defaults to
/// `gpt-4o-mini` and the base URL to `https://api.openai.com/v1`, both
/// overridable via `ZOVA_AI_MODEL` / `ZOVA_AI_BASE_URL`.
class OpenAiCompatibleAiBackend implements AiBackend {
  OpenAiCompatibleAiBackend({
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
    String? baseUrl,
    String? apiKey,
    String? model,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            (EnvConfig.aiBaseUrl.isEmpty
                ? 'https://api.openai.com/v1'
                : EnvConfig.aiBaseUrl),
        _apiKey = apiKey ?? EnvConfig.aiApiKey,
        _model = model ??
            (EnvConfig.aiModel.isEmpty ? 'gpt-4o-mini' : EnvConfig.aiModel);

  final http.Client _client;
  final Duration timeout;
  final String _baseUrl;
  final String _apiKey;
  final String _model;

  @override
  Future<String?> completeText(AiChatRequest request) async {
    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': request.system},
                {'role': 'user', 'content': request.user},
              ],
              'temperature': 0.3,
              'max_tokens': request.maxTokens ?? 1000,
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      return parseChatCompletions(response.body);
    } on Exception {
      return null;
    }
  }

  /// Extracts the completion text from a `/chat/completions` response body.
  static String? parseChatCompletions(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>? ?? const [];
      for (final raw in choices) {
        final choice = raw as Map<String, dynamic>;
        final message = choice['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) return content.trim();
      }
      return null;
    } on Exception {
      return null;
    }
  }
}

/// Returned when no API key is configured: answers nothing, never touches the
/// network, so an unconfigured build stays fully offline.
class UnconfiguredAiBackend implements AiBackend {
  const UnconfiguredAiBackend();

  @override
  Future<String?> completeText(AiChatRequest request) async => null;
}
