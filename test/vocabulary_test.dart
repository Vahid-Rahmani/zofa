import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zova/core/state/app_controller.dart';
import 'package:zova/core/state/language_controller.dart';
import 'package:zova/data/services/english_frequency.dart';
import 'package:zova/data/services/english_grammar.dart';
import 'package:zova/features/vocabulary/level_words_screen.dart';
import 'package:zova/features/vocabulary/vocabulary_screen.dart';

/// Anchor words placed at specific frequency ranks so every CEFR band has a
/// recognizable headword; the remaining ranks are filled with `f<rank>` words
/// to make a full 50,000-entry list (the bands assume that length).
const Map<int, String> kAnchors = {
  1: 'you', // A1
  3: 'the',
  6: 'be', // A1 verb
  8: 'this',
  50: 'apple', // A1 noun
  60: 'quickly', // A1 adverb
  500: 'happy', // A1 adjective
  1001: 'from', // A2
  1500: 'school', // A2
  2501: 'good', // B1
  3000: 'people', // B1
  5001: 'brother', // B2
  6000: 'explore', // B2
  10001: 'diamond', // C1
  10002: 'philosopher',
  10003: 'photosynthesis',
  12000: 'manufacture', // C1
  25001: 'quintessential', // C2
  26000: 'transformation', // C2
};

List<String> _buildFiftyThousand() {
  final words = List<String>.generate(50000, (i) => 'f${i + 1}');
  kAnchors.forEach((rank, word) => words[rank - 1] = word);
  return words;
}

Map<String, dynamic> _seedPos() => {
      'you': 'pronoun',
      'the': 'determiner',
      'be': 'verb',
      'this': 'pronoun',
      'apple': 'noun',
      'quickly': 'adverb',
      'happy': 'adjective',
      'from': 'preposition',
      'school': 'noun',
      'good': 'adjective',
      'people': 'noun',
      'brother': 'noun',
      'explore': 'verb',
      'diamond': 'noun',
      'philosopher': 'noun',
      'photosynthesis': 'noun',
      'manufacture': 'verb',
      'quintessential': 'adjective',
      'transformation': 'noun',
    };

Map<String, dynamic> _seedVerbs() => {
      'be': {'past': 'was/were', 'participle': 'been'},
      'run': {'past': 'ran', 'participle': 'run'},
      'go': {'past': 'went', 'participle': 'gone'},
      'stop': {'past': 'stopped', 'participle': 'stopped'},
    };

void main() {
  setUpAll(() {
    EnglishFrequencyList.seedAsset(
      EnglishFrequencyList.assetPath,
      jsonEncode(_buildFiftyThousand()),
    );
    EnglishGrammar.seedAsset(
      EnglishGrammar.posAssetPath,
      jsonEncode(_seedPos()),
    );
    EnglishGrammar.seedAsset(
      EnglishGrammar.verbsAssetPath,
      jsonEncode(_seedVerbs()),
    );
  });

  group('EnglishFrequencyList', () {
    test('loads 50,000 seeded words in frequency order', () async {
      final list = await EnglishFrequencyList.service;
      expect(list.length, 50000);
      expect(list.wordAtRank(1), 'you');
      expect(list.wordAtRank(50000), 'f50000');
    });

    test('rankOf is case-insensitive and null when absent', () async {
      final list = await EnglishFrequencyList.service;
      expect(list.rankOf('YOU'), 1);
      expect(list.rankOf('Be'), 6);
      expect(list.rankOf('missing'), isNull);
      expect(list.contains('school'), isTrue);
      expect(list.contains('missing'), isFalse);
    });

    test('levelForRank maps bands to CEFR levels', () async {
      final list = await EnglishFrequencyList.service;
      expect(list.levelForRank(1), 'A1');
      expect(list.levelForRank(1000), 'A1');
      expect(list.levelForRank(1001), 'A2');
      expect(list.levelForRank(2500), 'A2');
      expect(list.levelForRank(2501), 'B1');
      expect(list.levelForRank(5000), 'B1');
      expect(list.levelForRank(5001), 'B2');
      expect(list.levelForRank(10000), 'B2');
      expect(list.levelForRank(10001), 'C1');
      expect(list.levelForRank(25000), 'C1');
      expect(list.levelForRank(25001), 'C2');
      expect(list.levelForRank(50000), 'C2');
      expect(list.levelForRank(50001), isNull);
    });

    test('levelForWord resolves and wordsForLevel slices the bands', () async {
      final list = await EnglishFrequencyList.service;
      expect(list.levelForWord('you'), 'A1');
      expect(list.levelForWord('people'), 'B1');
      expect(list.levelForWord('manufacture'), 'C1');
      expect(list.levelForWord('transformation'), 'C2');
      expect(list.levelForWord('missing'), isNull);

      expect(list.wordsForLevel('A1').length, 1000);
      expect(list.wordsForLevel('A1').first, 'you');
      expect(list.wordsForLevel('B1').first, 'good');
      expect(list.countForLevel('A1'), 1000);
      expect(list.countForLevel('A2'), 1500);
      expect(list.countForLevel('C2'), 25000);
      expect(list.countForLevel('not-a-level'), 0);
    });

    test('suggestions return frequency-ordered prefix matches', () async {
      final list = await EnglishFrequencyList.service;
      expect(list.suggestions('ph'), ['philosopher', 'photosynthesis']);
      expect(list.suggestions('bro'), ['brother']);
      expect(list.suggestions(''), isEmpty);
    });

    test('wordOfDay skips top function words and is deterministic', () async {
      final list = await EnglishFrequencyList.service;
      final date = DateTime(2026, 8, 3);
      expect(list.wordOfDay(date), isNotEmpty);
      expect(list.wordOfDay(date), list.wordOfDay(date));
    });
  });

  group('VocabularyScreen', () {
    Widget wrap(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppController()),
          ChangeNotifierProvider(create: (_) => LanguageController()),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('shows the six CEFR levels with word counts', (tester) async {
      await tester.pumpWidget(wrap(const VocabularyScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vocabulary'), findsOneWidget);
      expect(
        find.textContaining('50000'),
        findsOneWidget,
        reason: 'header mentions the 50k word count',
      );
      // The level cards live in one ListView; the lower levels render lazily.
      for (final level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']) {
        await tester.scrollUntilVisible(
          find.text(level),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(level), findsOneWidget);
      }
      expect(find.text('Beginner'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Proficient'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Proficient'), findsOneWidget);
    });

    testWidgets('tapping a level opens the word list', (tester) async {
      await tester.pumpWidget(wrap(const VocabularyScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();
      expect(find.byType(LevelWordsScreen), findsOneWidget);
    });
  });

  group('LevelWordsScreen', () {
    Widget wrap(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppController()),
          ChangeNotifierProvider(create: (_) => LanguageController()),
        ],
        child: MaterialApp(home: child),
      );
    }

    testWidgets('opens on the level themes and drills into one', (tester) async {
      await tester.pumpWidget(wrap(const LevelWordsScreen(level: 'A1')));
      await tester.pumpAndSettle();

      // The screen opens on the level header and its themed category cards.
      expect(find.text('A1 · Beginner'), findsOneWidget);
      expect(find.textContaining('1000 words'), findsOneWidget);
      expect(find.text('Verbs'), findsOneWidget);
      expect(find.text('Food & Drinks'), findsOneWidget);

      // Opening a theme shows only that theme's words, with rank badges.
      await tester.tap(find.text('Food & Drinks'));
      await tester.pumpAndSettle();
      expect(find.text('apple'), findsOneWidget);
      expect(find.text('#50'), findsOneWidget);
      expect(find.text('be'), findsNothing);

      // Back returns to the category grid.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('A1 · Beginner'), findsOneWidget);

      // Verb words carry their part of speech as the badge.
      await tester.tap(find.text('Verbs'));
      await tester.pumpAndSettle();
      expect(find.text('be'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);

      // Untagged function words land in the trailing "Other words" theme.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other words'));
      await tester.pumpAndSettle();
      expect(find.text('you'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('filter narrows the words of a theme', (tester) async {
      await tester.pumpWidget(wrap(const LevelWordsScreen(level: 'B1')));
      await tester.pumpAndSettle();

      // 'good' is B1's adjective; the adjective theme holds it.
      await tester.tap(find.text('Adjectives'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'good');
      await tester.pump();

      expect(
        find.descendant(of: find.byType(Card), matching: find.text('good')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(Card), matching: find.text('people')),
        findsNothing,
      );
    });
  });
}
