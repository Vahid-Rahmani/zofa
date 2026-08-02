import 'package:flutter_test/flutter_test.dart';
import 'package:zova/core/utils/clean_text.dart';

void main() {
  group('cleanText', () {
    test('strips plain HTML tags with attributes', () {
      expect(
        cleanText('<a rel="mw:WikiLink" href="/wiki/House">house</a>'),
        'house',
      );
      expect(cleanText('<b>strong</b> and <span class="gloss">plain</span>'),
          'strong and plain');
    });

    test('removes script and style blocks entirely', () {
      expect(
        cleanText('<script>alert(1)</script>Visible<style>p{color:red}</style>'),
        'Visible',
      );
    });

    test('decodes named and numeric HTML entities', () {
      expect(cleanText('Tom &amp; Jerry'), 'Tom & Jerry');
      expect(cleanText('&quot;Hello&quot; &mdash; she said &nbsp;'),
          '"Hello" — she said');
      expect(cleanText('&#8220;quoted&#8221;'), '“quoted”',
          reason: '8220/8221 are the typographic curly quotes');
      expect(cleanText('&#x6A9;'), 'ک', reason: 'hex codepoint for kaf');
    });

    test('strips wiki markup, templates and links', () {
      expect(cleanText("he '''wrote''' the '''''book'''''"), 'he wrote the book');
      expect(cleanText('[[Berlin]] is [[the capital|the capital city]]'),
          'Berlin is the capital city');
      expect(cleanText('See {{lang|de|Haus}} now'), 'See now');
      expect(cleanText('Read [https://example.com more here]'), 'Read more here');
    });

    test('keeps clean Persian and English text unchanged', () {
      expect(cleanText('سیب قرمز روی میز است'), 'سیب قرمز روی میز است');
      expect(cleanText('The quick brown fox.'), 'The quick brown fox.');
    });

    test('collapses runs of whitespace', () {
      expect(cleanText('a   b\n\t c'), 'a b c');
      expect(cleanText('  leading and trailing  '), 'leading and trailing');
    });

    test('handles Wiktionary-style definition soup', () {
      const soup =
          '<span class="quote"><i><a rel="mw:WikiLink" href="/wiki/'
          'fear">Fear</a></i> is a feeling</span> ({{pl|fears}}) — "&quot;'
          'I fear nothing&quot;"';
      final cleaned = cleanText(soup);
      expect(cleaned, contains('Fear is a feeling'));
      expect(cleaned, isNot(contains('<')));
      expect(cleaned, isNot(contains('>')));
      expect(cleaned, isNot(contains('&')));
    });

    test('is safe on empty and already-clean input', () {
      expect(cleanText(''), '');
      expect(cleanText('plain text'), 'plain text');
    });
  });
}
