import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/models/ai_grammar_explanation.dart';
import 'package:zova/data/models/ai_word_details.dart';
import 'package:zova/data/services/ai_backend.dart';
import 'package:zova/data/services/ai_cache.dart';
import 'package:zova/data/services/ai_tutor_service.dart';

class FakeAiBackend implements AiBackend {
  final Map<String, String?> responses = {};

  /// Fallback reply used for every request (the prompt text is generated, so
  /// tests usually do not key on it).
  String? response;
  Object? error;
  int calls = 0;
  final List<AiChatRequest> requests = [];

  @override
  Future<String?> completeText(AiChatRequest request) async {
    calls++;
    requests.add(request);
    if (error != null) throw error!;
    return responses[request.user] ?? response;
  }
}

const String _wordDetailsJson = '''
```json
{
  "translation": "سلام",
  "phonetic": "/həˈloʊ/",
  "part_of_speech": "noun",
  "gender": null,
  "definition": "a greeting",
  "examples": [
    {"sentence": "Hello!", "translation": "سلام!"}
  ],
  "alternates": ["درود", "hi"]
}
```
''';

void main() {
  late FakeAiBackend backend;
  late AiTutorService service;

  setUp(() {
    backend = FakeAiBackend();
    service = AiTutorService(
      backend: backend,
      cache: MemoryAiCache(),
      enabled: true,
    );
  });

  group('AiWordDetails', () {
    test('parses a fenced Gemini-style JSON reply', () {
      final details = AiTutorService.parseWordDetails(
        _wordDetailsJson,
        word: 'hello',
        source: 'en',
        target: 'fa',
      );

      expect(details, isNotNull);
      expect(details!.translation, 'سلام');
      expect(details.phonetic, '/həˈloʊ/');
      expect(details.partOfSpeech, 'noun');
      expect(details.definition, 'a greeting');
      expect(details.examples, hasLength(1));
      expect(details.examples.first.sentence, 'Hello!');
      expect(details.alternates, ['درود', 'hi']);
    });

    test('returns null when no usable translation is present', () {
      expect(
        AiTutorService.parseWordDetails(
          '{"phonetic": "/x/"}',
          word: 'x',
          source: 'en',
          target: 'fa',
        ),
        isNull,
      );
    });

    test('returns null on malformed JSON', () {
      expect(
        AiTutorService.parseWordDetails(
          'not json at all',
          word: 'x',
          source: 'en',
          target: 'fa',
        ),
        isNull,
      );
    });

    test('round-trips through JSON', () {
      final details = AiWordDetails(
        word: 'haus',
        source: 'de',
        target: 'fa',
        translation: 'خانه',
        phonetic: '/haʊs/',
        gender: 'das Haus',
        partOfSpeech: 'noun',
        definition: 'a building',
        examples: const [
          AiExample(
              sentence: 'Das Haus ist gross.', translation: 'خانه بزرگ است.'),
        ],
        alternates: const ['ساختمان'],
        cachedAt: DateTime.utc(2026, 1, 1),
      );
      final restored = AiWordDetails.fromJson(details.toJson());
      expect(restored.translation, details.translation);
      expect(restored.gender, 'das Haus');
      expect(restored.examples, hasLength(1));
      expect(restored.cachedAt, details.cachedAt);
    });
  });

  group('AiGrammarExplanation', () {
    test('parses summary, explanation, examples and tip', () {
      final parsed = AiTutorService.parseGrammarExplanation(
        '''
        {"summary": "Use the for known things.",
         "explanation": "Full text here.",
         "examples": [{"sentence": "The cat is black.",
                        "translation": "گربه سیاه است."}],
         "tip": "an before vowels"}
        ''',
        topic: 'articles',
      );

      expect(parsed, isNotNull);
      expect(parsed!.topic, 'articles');
      expect(parsed.summary, 'Use the for known things.');
      expect(parsed.examples, hasLength(1));
      expect(parsed.tip, 'an before vowels');
    });

    test('returns null when neither summary nor explanation exists', () {
      expect(
        AiTutorService.parseGrammarExplanation(
          '{"tip": "hi"}',
          topic: 'x',
        ),
        isNull,
      );
    });

    test('round-trips through JSON', () {
      final explanation = AiGrammarExplanation(
        topic: 'plurals',
        summary: 'Add -s',
        explanation: 'Most nouns add -s.',
        examples: const [
          AiExample(
              sentence: 'One cat, two cats.', translation: 'یک گربه، دو گربه.'),
        ],
        tip: 'watch for -es',
        cachedAt: DateTime.utc(2026, 2, 2),
      );
      final restored = AiGrammarExplanation.fromJson(explanation.toJson());
      expect(restored.summary, explanation.summary);
      expect(restored.examples, hasLength(1));
      expect(restored.tip, explanation.tip);
    });
  });

  group('wordDetails', () {
    test('queries the model, caches, and repeats are served from cache',
        () async {
      backend.response = _wordDetailsJson;

      final first = await service.wordDetails(
        word: 'hello',
        source: 'en',
        target: 'fa',
      );
      expect(first, isNotNull);
      expect(first!.translation, 'سلام');
      expect(first.fromCache, isFalse);

      final second = await service.wordDetails(
        word: 'hello',
        source: 'en',
        target: 'fa',
      );
      expect(second, isNotNull);
      expect(second!.fromCache, isTrue);
      expect(backend.calls, 1, reason: 'cached repeat must not hit the model');
    });

    test('forceRefresh bypasses the cache', () async {
      backend.response = _wordDetailsJson;
      await service.wordDetails(word: 'hello', source: 'en', target: 'fa');
      final refreshed = await service.wordDetails(
        word: 'hello',
        source: 'en',
        target: 'fa',
        forceRefresh: true,
      );
      expect(refreshed!.fromCache, isFalse);
      expect(backend.calls, 2);
    });

    test('returns null when the backend is unavailable', () async {
      backend.error = Exception('rate limited');
      final result = await service.wordDetails(
        word: 'hello',
        source: 'en',
        target: 'fa',
      );
      expect(result, isNull);
    });

    test('returns null on a malformed reply', () async {
      backend.response = 'oops';
      final result = await service.wordDetails(
        word: 'hello',
        source: 'en',
        target: 'fa',
      );
      expect(result, isNull);
    });
  });

  group('explainGrammar', () {
    test('queries the model, caches, and repeats are served from cache',
        () async {
      backend.response = '''
        {"summary": "Use the for known things.",
         "explanation": "Full text here.",
         "examples": [{"sentence": "The cat is black.", "translation": "G."}],
         "tip": null}
      ''';

      final first = await service.explainGrammar(
        topicOrQuestion: 'articles',
        source: 'en',
        target: 'fa',
      );
      expect(first, isNotNull);
      expect(first!.summary, 'Use the for known things.');
      expect(first.fromCache, isFalse);

      final second = await service.explainGrammar(
        topicOrQuestion: 'articles',
        source: 'en',
        target: 'fa',
      );
      expect(second!.fromCache, isTrue);
      expect(backend.calls, 1);
    });

    test('returns null when the model fails', () async {
      backend.error = Exception('down');
      final result = await service.explainGrammar(
        topicOrQuestion: 'plurals',
        source: 'en',
        target: 'fa',
      );
      expect(result, isNull);
    });
  });

  group('askTutor', () {
    test('returns the raw answer and caches it', () async {
      backend.response = 'Because the points at a specific noun.';
      final first = await service.askTutor(
        question: 'why is the before nouns?',
        source: 'en',
        target: 'fa',
      );
      expect(first, isNotNull);
      expect(first!.answer, 'Because the points at a specific noun.');
      expect(first.fromCache, isFalse);

      final second = await service.askTutor(
        question: 'why is the before nouns?',
        source: 'en',
        target: 'fa',
      );
      expect(second!.fromCache, isTrue);
      expect(backend.calls, 1);
    });

    test('returns null when the answer is empty', () async {
      backend.response = '   ';
      final result = await service.askTutor(
        question: 'q',
        source: 'en',
        target: 'fa',
      );
      expect(result, isNull);
    });
  });

  group('configuration', () {
    test('a disabled service never touches the backend', () async {
      final disabled = AiTutorService(
        backend: backend,
        cache: MemoryAiCache(),
        enabled: false,
      );
      expect(disabled.isConfigured, isFalse);
      expect(
        await disabled.wordDetails(word: 'x', source: 'en', target: 'fa'),
        isNull,
      );
      expect(backend.calls, 0);
    });

    test('UnconfiguredAiBackend answers nothing', () async {
      const unconfigured = UnconfiguredAiBackend();
      expect(
        await unconfigured.completeText(
          const AiChatRequest(system: 's', user: 'u'),
        ),
        isNull,
      );
    });
  });

  group('backend response parsing', () {
    test('Gemini generateContent text extraction', () {
      const body = '''
        {"candidates":[{"content":{"parts":[{"text":"hello "},{"text":"world"}]}}]}
      ''';
      expect(GeminiAiBackend.parseGenerateContent(body), 'hello world');
    });

    test('Gemini parse tolerates an empty response', () {
      expect(GeminiAiBackend.parseGenerateContent('{}'), isNull);
    });

    test('OpenAI chat completions content extraction', () {
      const body = '''
        {"choices":[{"message":{"content":"Answer here"}}]}
      ''';
      expect(
        OpenAiCompatibleAiBackend.parseChatCompletions(body),
        'Answer here',
      );
    });

    test('OpenAI parse tolerates malformed body', () {
      expect(OpenAiCompatibleAiBackend.parseChatCompletions('nope'), isNull);
    });
  });

  group('cache keys', () {
    test('word keys normalise case, punctuation and whitespace', () {
      expect(
        AiTutorService.wordCacheKey(
            word: 'Good Morning', source: 'en', target: 'fa'),
        AiTutorService.wordCacheKey(
            word: 'good morning!', source: 'en', target: 'fa'),
      );
    });

    test('distinct languages produce distinct keys', () {
      expect(
        AiTutorService.wordCacheKey(word: 'haus', source: 'de', target: 'fa'),
        isNot(
          AiTutorService.wordCacheKey(word: 'haus', source: 'de', target: 'en'),
        ),
      );
    });
  });

  group('MemoryAiCache', () {
    test('put/get/remove/clear and LRU eviction', () async {
      final cache = MemoryAiCache(capacity: 2);
      expect(await cache.length, 0);

      await cache.put('a', '1');
      await cache.put('b', '2');
      await cache.put('c', '3');
      expect(await cache.get('a'), isNull, reason: 'oldest entry is evicted');
      expect(await cache.get('b'), '2');
      expect(await cache.get('c'), '3');

      await cache.put('b', '22');
      await cache.remove('c');
      expect(await cache.get('b'), '22');
      expect(await cache.get('c'), isNull);

      await cache.clear();
      expect(await cache.length, 0);
    });
  });
}
