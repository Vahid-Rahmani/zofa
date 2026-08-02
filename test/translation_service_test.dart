import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/translation_result.dart';
import 'package:zova/data/services/translation_backend.dart';
import 'package:zova/data/services/translation_cache.dart';
import 'package:zova/data/services/translation_service.dart';

class FakeTranslationBackend implements TranslationBackend {
  final Map<String, TranslationResult> results = {};
  Object? error;
  int calls = 0;
  final List<TranslationRequest> requests = [];

  @override
  Future<TranslationResult?> lookup(TranslationRequest request) async {
    calls++;
    requests.add(request);
    if (error != null) throw error!;
    return results['${request.source}|${request.target}|${request.word.toLowerCase()}'];
  }
}

TranslationResult _result(String word, String translation) => TranslationResult(
      word: word,
      source: 'en',
      target: 'fa',
      translation: translation,
    );

void main() {
  late FakeTranslationBackend backend;
  late TranslationService service;

  setUp(() {
    backend = FakeTranslationBackend();
    backend.results['en|fa|hello'] = _result('hello', 'سلام');
    service = TranslationService(
      backend: backend,
      cache: MemoryTranslationCache(),
    );
  });

  test('first lookup hits the backend, the repeat is served from cache', () async {
    final first = await service.lookup(word: 'hello', source: 'en', target: 'fa');
    expect(first.fromCache, isFalse);
    expect(first.translation, 'سلام');

    final second = await service.lookup(word: 'hello', source: 'en', target: 'fa');
    expect(second.fromCache, isTrue);
    expect(backend.calls, 1, reason: 'cached repeat must not hit the backend');
  });

  test('forceRefresh bypasses the cache', () async {
    await service.lookup(word: 'hello', source: 'en', target: 'fa');
    final refreshed =
        await service.lookup(word: 'hello', source: 'en', target: 'fa', forceRefresh: true);
    expect(refreshed.fromCache, isFalse);
    expect(backend.calls, 2);
  });

  test('backend failure falls back to the cached copy (offline mode)', () async {
    await service.lookup(word: 'hello', source: 'en', target: 'fa');
    backend.error = Exception('network down');

    final result = await service.lookup(word: 'hello', source: 'en', target: 'fa');
    expect(result.fromCache, isTrue);
    expect(result.translation, 'سلام');
  });

  test('backend failure without a cache entry throws TranslationException', () async {
    backend.error = Exception('network down');
    await expectLater(
      service.lookup(word: 'missing', source: 'en', target: 'fa'),
      throwsA(isA<TranslationException>()),
    );
  });

  test('empty queries are rejected', () async {
    await expectLater(
      service.lookup(word: '   ', source: 'en', target: 'fa'),
      throwsA(isA<TranslationException>()),
    );
  });

  test('cacheKey normalises case, punctuation and whitespace', () {
    expect(
      TranslationService.cacheKey(source: 'en', target: 'fa', word: 'Good Morning'),
      TranslationService.cacheKey(source: 'en', target: 'fa', word: 'good morning!'),
    );
  });

  test('lookupAnySource tries candidate sources in order', () async {
    final any = FakeTranslationBackend();
    any.results['de|fa|liebe'] = const TranslationResult(
      word: 'liebe',
      source: 'de',
      target: 'fa',
      translation: 'عشق',
    );
    final serviceAny = TranslationService(
      backend: any,
      cache: MemoryTranslationCache(),
    );

    final result = await serviceAny.lookupAnySource(word: 'liebe', target: 'fa');
    expect(result?.translation, 'عشق');
    expect(any.requests.map((r) => r.source).toList(), ['en', 'de'],
        reason: 'English is tried first, then German');
  });

  test('clearCache forces a fresh lookup', () async {
    await service.lookup(word: 'hello', source: 'en', target: 'fa');
    await service.clearCache();
    final result = await service.lookup(word: 'hello', source: 'en', target: 'fa');
    expect(result.fromCache, isFalse);
    expect(backend.calls, 2);
  });
}
