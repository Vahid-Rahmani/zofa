import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zova/data/services/english_grammar.dart';

Map<String, dynamic> _pos() => {
      'run': 'verb',
      'be': 'verb',
      'go': 'verb',
      'study': 'verb',
      'want': 'verb',
      'like': 'verb',
      'school': 'noun',
      'apple': 'noun',
      'good': 'adjective',
      'quickly': 'adverb',
      'you': 'pronoun',
    };

Map<String, dynamic> _verbs() => {
      'be': {'past': 'was/were', 'participle': 'been'},
      'run': {'past': 'ran', 'participle': 'run'},
      'go': {'past': 'went', 'participle': 'gone'},
      'say': {'past': 'said', 'participle': 'said'},
      'make': {'past': 'made', 'participle': 'made'},
    };

void main() {
  setUpAll(() {
    EnglishGrammar.seedAsset(EnglishGrammar.posAssetPath, jsonEncode(_pos()));
    EnglishGrammar.seedAsset(
      EnglishGrammar.verbsAssetPath,
      jsonEncode(_verbs()),
    );
  });

  group('EnglishGrammar', () {
    test('resolves part of speech and broad section', () async {
      final grammar = await EnglishGrammar.service;
      expect(grammar.partOfSpeech('run'), 'verb');
      expect(grammar.partOfSpeech('SCHOOL'), 'noun');
      expect(grammar.partOfSpeech('missing'), isNull);

      expect(grammar.sectionOf('run'), EnglishSection.verb);
      expect(grammar.sectionOf('school'), EnglishSection.noun);
      expect(grammar.sectionOf('good'), EnglishSection.adjective);
      expect(grammar.sectionOf('quickly'), EnglishSection.adverb);
      expect(grammar.sectionOf('you'), EnglishSection.other);
      expect(grammar.sectionOf('missing'), EnglishSection.other);

      expect(grammar.isVerb('run'), isTrue);
      expect(grammar.isVerb('school'), isFalse);
    });

    test('builds the active/passive conjugation table for irregular verbs',
        () async {
      final grammar = await EnglishGrammar.service;
      final forms = grammar.verbForms('run');
      expect(forms, isNotNull);
      expect(forms!.present, 'run');
      expect(forms.past, 'ran');
      expect(forms.future, 'will run');
      expect(forms.presentPassive, 'am/is/are run');
      expect(forms.pastPassive, 'was/were run');
      expect(forms.futurePassive, 'will be run');
      expect(forms.active, ['run', 'ran', 'will run']);
      expect(
        forms.passive,
        ['am/is/are run', 'was/were run', 'will be run'],
      );
    });

    test('inflects regular verbs with standard spelling rules', () async {
      final grammar = await EnglishGrammar.service;
      expect(grammar.verbForms('want')!.past, 'wanted');
      expect(grammar.verbForms('study')!.past, 'studied');
      expect(grammar.verbForms('like')!.past, 'liked');
    });

    test('resolves inflected forms back to the lemma', () async {
      final grammar = await EnglishGrammar.service;
      expect(grammar.lemma('said'), 'say');
      expect(grammar.lemma('went'), 'go');
      expect(grammar.lemma('made'), 'make');
      expect(grammar.lemma('running'), 'run');
      expect(grammar.lemma('walks'), 'walk');
      expect(grammar.lemma('run'), 'run');
    });

    test('returns no verb table for non-verbs', () async {
      final grammar = await EnglishGrammar.service;
      expect(grammar.verbForms('school'), isNull);
      expect(grammar.verbForms('missing'), isNull);
    });

    test('generates example sentences per part of speech', () async {
      final grammar = await EnglishGrammar.service;
      expect(grammar.exampleSentences('run', EnglishSection.verb), [
        'I want to run.',
        'We will run tomorrow.',
        'They like to run every day.',
      ]);
      expect(grammar.exampleSentences('school', EnglishSection.noun), [
        'I see the school.',
        'The school is here.',
      ]);
      expect(grammar.exampleSentences('good', EnglishSection.adjective), [
        'It is very good.',
        'This looks good.',
        'She feels good.',
      ]);
      expect(grammar.exampleSentences('quickly', EnglishSection.adverb), [
        'He runs quickly.',
        'She speaks quickly.',
        'They work quickly.',
      ]);
      expect(grammar.exampleSentences('you', EnglishSection.other), isEmpty);
    });
  });
}
