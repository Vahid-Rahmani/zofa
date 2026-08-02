import '../models/translation_result.dart';
import 'normalize.dart' as normalize;
import 'translation_backend.dart';
import 'translation_cache.dart';

/// Raised when a translation lookup cannot be satisfied.
class TranslationException implements Exception {
  const TranslationException(this.message, {this.offline = false});

  /// Human-readable reason, safe to show to the learner.
  final String message;

  /// True when the failure looks like a connectivity problem.
  final bool offline;

  @override
  String toString() => message;
}

/// The dynamic translation/lookup bridge.
///
/// This is the primary dictionary data source: instead of shipping bundled
/// JSON word lists, the app queries a real-time provider for any word and any
/// language pair, keeps results in a local LRU/Hive cache, and transparently
/// falls back to cached results when the network is unavailable.
///
/// Use [instance] (set once at startup in `main.dart`, and swapped for a fake
/// backend in widget tests).
class TranslationService {
  TranslationService({
    required TranslationBackend backend,
    required TranslationCache cache,
  })  : _backend = backend,
        _cache = cache;

  /// The shared app-wide instance. Reassign in tests via a fake backend and
  /// in-memory cache.
  static TranslationService instance = TranslationService(
    backend: buildDefaultTranslationBackend(),
    cache: MemoryTranslationCache(),
  );

  final TranslationBackend _backend;
  final TranslationCache _cache;

  /// Canonical cache key for a lookup. The word is normalised so casing,
  /// punctuation and whitespace collapse to a single key.
  static String cacheKey({
    required String source,
    required String target,
    required String word,
  }) =>
      '$source|$target|${normalize.slug(normalize.normalizeText(word))}';

  /// Looks up [word] from [source] into [target].
  ///
  /// Order of operations:
  /// 1. Serve from the local cache when present (instant, offline-ready).
  /// 2. Otherwise query the backend and cache the result.
  /// 3. If the backend fails, fall back to any cached copy of the word.
  /// 4. With neither, throw [TranslationException].
  ///
  /// Set [forceRefresh] to bypass the cache and re-fetch from the provider.
  Future<TranslationResult> lookup({
    required String word,
    required String source,
    required String target,
    bool forceRefresh = false,
  }) async {
    final query = word.trim();
    if (query.isEmpty) {
      throw const TranslationException('Enter a word to look up.');
    }
    final key = cacheKey(source: source, target: target, word: query);

    if (!forceRefresh) {
      final cached = await _cache.get(key);
      if (cached != null) {
        return cached.copyWith(fromCache: true);
      }
    }

    TranslationResult? result;
    try {
      result = await _backend
          .lookup(TranslationRequest(word: query, source: source, target: target));
    } on Exception {
      result = null;
    }

    if (result != null && !result.isEmpty) {
      await _cache.put(key, result);
      return result.copyWith(fromCache: false);
    }

    final stale = await _cache.get(key);
    if (stale != null) {
      return stale.copyWith(fromCache: true);
    }
    throw TranslationException(
      'Couldn’t translate "$query". Check your connection and try again.',
      offline: true,
    );
  }

  /// Looks up [word] across several candidate [sources] into [target], returning
  /// the first provider/cache hit. Used where the source language of a saved
  /// word is unknown (e.g. "My Words" bookmarks which only store the string).
  Future<TranslationResult?> lookupAnySource({
    required String word,
    required String target,
    List<String> sources = const ['en', 'de'],
  }) async {
    TranslationException? lastError;
    for (final source in sources) {
      try {
        final result =
            await lookup(word: word, source: source, target: target);
        if (!result.isEmpty) return result;
      } on TranslationException catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }

  /// Number of entries currently held in the cache.
  Future<int> get cacheLength => _cache.length;

  /// Empties the translation cache.
  Future<void> clearCache() => _cache.clear();
}
