import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/models/language_settings.dart';
import 'package:zova/data/services/ai_backend.dart';
import 'package:zova/data/services/ai_cache.dart';
import 'package:zova/data/services/ai_tutor_service.dart';
import 'package:zova/data/services/grammar_content.dart';
import 'package:zova/features/grammar/grammar_screen.dart';

/// Returns a canned explanation for every request so the screen can be
/// exercised without a real model.
class FakeAiBackend implements AiBackend {
  String response = '';
  Object? error;
  int calls = 0;

  @override
  Future<String?> completeText(AiChatRequest request) async {
    calls++;
    if (error != null) throw error!;
    return response;
  }
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppController()),
      ChangeNotifierProvider(
        create: (_) => LanguageController(initial: const LanguageSettings()),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  late FakeAiBackend backend;

  setUp(() {
    backend = FakeAiBackend();
    AiTutorService.instance = AiTutorService(
      backend: backend,
      cache: MemoryAiCache(),
      enabled: true,
    );
  });

  tearDown(() {
    AiTutorService.instance = AiTutorService(
      backend: buildDefaultAiBackend(),
      cache: MemoryAiCache(),
    );
  });

  /// The AI section sits below the static topic content, so use a tall
  /// viewport to keep the whole ListView inflated.
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('every grammar topic auto-loads its AI explanation',
      (tester) async {
    await useTallViewport(tester);
    backend.response = '''
      {"summary": "Use the before specific things.",
       "explanation": "Full explanation here.",
       "examples": [{"sentence": "The cat is black.",
                      "translation": "گربه سیاه است."}],
       "tip": "an before vowels"}
    ''';

    final topic = GrammarContent.topics.first;
    await tester.pumpWidget(_wrap(GrammarDetailScreen(topic: topic)));
    await tester.pumpAndSettle();

    expect(backend.calls, 1,
        reason: 'opening the topic must fetch the AI explanation');
    expect(
        find.textContaining('Use the before specific things.'), findsOneWidget);
    expect(find.textContaining('Full explanation here.'), findsOneWidget);
    expect(find.textContaining('an before vowels'), findsOneWidget);
  });

  testWidgets('reopening a topic serves its explanation from cache',
      (tester) async {
    await useTallViewport(tester);
    backend.response =
        '{"summary": "Cached summary.", "explanation": "Cached body."}';

    final a = GrammarContent.topics.first;
    final b = GrammarContent.topics.last;

    await tester.pumpWidget(_wrap(
      KeyedSubtree(key: ValueKey(a.id), child: GrammarDetailScreen(topic: a)),
    ));
    await tester.pumpAndSettle();
    expect(backend.calls, 1);

    await tester.pumpWidget(_wrap(
      KeyedSubtree(key: ValueKey(b.id), child: GrammarDetailScreen(topic: b)),
    ));
    await tester.pumpAndSettle();
    expect(backend.calls, 2, reason: 'a new topic is a new request');

    await tester.pumpWidget(_wrap(
      KeyedSubtree(key: ValueKey(a.id), child: GrammarDetailScreen(topic: a)),
    ));
    await tester.pumpAndSettle();
    expect(backend.calls, 2,
        reason: 'reopening topic a must be served from cache, not the model');
    expect(find.textContaining('Cached summary.'), findsOneWidget);
  });
}
