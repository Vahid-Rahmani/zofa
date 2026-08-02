import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zova/data/models/translation_result.dart';
import 'package:zova/data/services/translation_cache.dart';

TranslationResult _result(String word) => TranslationResult(
      word: word,
      source: 'en',
      target: 'fa',
      translation: 'gloss-$word',
    );

void main() {
  group('MemoryTranslationCache', () {
    test('stores and returns entries', () async {
      final cache = MemoryTranslationCache();
      await cache.put('a', _result('apple'));
      expect((await cache.get('a'))?.word, 'apple');
      expect(await cache.length, 1);
    });

    test('evicts the least recently used entry when at capacity', () async {
      final cache = MemoryTranslationCache(capacity: 2);
      await cache.put('a', _result('apple'));
      await cache.put('b', _result('bread'));
      await cache.get('a'); // 'a' becomes most recent
      await cache.put('c', _result('cat')); // evicts 'b'

      expect(await cache.get('a'), isNotNull);
      expect(await cache.get('b'), isNull, reason: 'oldest entry evicted');
      expect(await cache.get('c'), isNotNull);
      expect(await cache.length, 2);
    });

    test('put refreshes recency of an existing key', () async {
      final cache = MemoryTranslationCache(capacity: 2);
      await cache.put('a', _result('apple'));
      await cache.put('b', _result('bread'));
      await cache.put('a', _result('apple2')); // touches 'a'
      await cache.put('c', _result('cat')); // evicts 'b', keeps 'a'

      expect((await cache.get('a'))?.translation, 'gloss-apple2');
      expect(await cache.get('b'), isNull);
    });

    test('remove and clear work', () async {
      final cache = MemoryTranslationCache();
      await cache.put('a', _result('apple'));
      await cache.put('b', _result('bread'));
      await cache.remove('a');
      expect(await cache.get('a'), isNull);
      expect(await cache.length, 1);
      await cache.clear();
      expect(await cache.length, 0);
    });
  });

  group('HiveTranslationCache', () {
    test('persists to disk and hydrates into a new instance', () async {
      final dir = await Directory.systemTemp.createTemp('zova_hive_cache_');
      Hive.init(dir.path);
      const boxName = 'hive_test_cache';

      final cache = HiveTranslationCache(boxName: boxName);
      await cache.put('a', _result('apple'));
      await cache.put('b', _result('bread'));
      expect(await cache.get('a'), isNotNull);

      final reopened = HiveTranslationCache(boxName: boxName);
      expect(
        (await reopened.get('a'))?.translation,
        'gloss-apple',
        reason: 'a second instance hydrates the same box from disk',
      );

      await cache.clear();
      expect(await cache.get('a'), isNull);
      expect(await cache.get('b'), isNull);
      final fresh = HiveTranslationCache(boxName: boxName);
      expect(
        await fresh.get('a'),
        isNull,
        reason: 'a fresh instance sees the cleared box on disk',
      );

      await Hive.close();
      Hive.deleteFromDisk();
      await dir.delete(recursive: true);
    });
  });
}
