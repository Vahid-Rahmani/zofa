import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/translation_result.dart';

/// Local cache of translation results.
///
/// Lookups are stored so repeating a search is instant and recently viewed
/// words still work offline. Keys are the canonical cache keys produced by
/// [TranslationService.cacheKey] (`source|target|slug`).
abstract class TranslationCache {
  /// Returns the cached result for [key], or `null` when absent.
  Future<TranslationResult?> get(String key);

  /// Stores [result] under [key].
  Future<void> put(String key, TranslationResult result);

  /// Removes [key] from the cache.
  Future<void> remove(String key);

  /// Empties the cache.
  Future<void> clear();

  /// Number of cached entries.
  Future<int> get length;
}

/// In-memory LRU cache with a bounded capacity.
///
/// The most recently used entries are kept, the least recently used entry is
/// evicted once [capacity] is exceeded. This is the hot layer that makes
/// repeat searches instant within a session.
class MemoryTranslationCache implements TranslationCache {
  MemoryTranslationCache({this.capacity = 500})
      : assert(capacity > 0, 'capacity must be positive');

  /// Maximum number of entries kept in memory.
  final int capacity;

  final Map<String, TranslationResult> _entries = {};

  /// Keys ordered oldest-first; the most recently used key sits at the end.
  final List<String> _order = [];

  @override
  Future<TranslationResult?> get(String key) async {
    final result = _entries[key];
    if (result == null) return null;
    _touch(key);
    return result;
  }

  @override
  Future<void> put(String key, TranslationResult result) async {
    if (_entries.containsKey(key)) {
      _entries[key] = result;
      _touch(key);
    } else {
      _entries[key] = result;
      _order.add(key);
      _evict();
    }
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
    _order.remove(key);
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _order.clear();
  }

  @override
  Future<int> get length async => _entries.length;

  /// Internal LRU order (oldest first), exposed for tests.
  @visibleForTesting
  List<String> get order => List.unmodifiable(_order);

  void _touch(String key) {
    _order.remove(key);
    _order.add(key);
  }

  void _evict() {
    while (_order.length > capacity) {
      final oldest = _order.removeAt(0);
      _entries.remove(oldest);
    }
  }
}

/// Persistent cache backed by a Hive box, layered on top of a
/// [MemoryTranslationCache] hot layer.
///
/// On [open] the box is hydrated into memory so that repeated lookups are
/// served instantly without disk I/O, and every write is mirrored to disk so
/// recently viewed words survive app restarts and work offline.
class HiveTranslationCache implements TranslationCache {
  HiveTranslationCache({
    this.capacity = 500,
    this.boxName = 'translation_cache',
  }) : _memory = MemoryTranslationCache(capacity: capacity);

  final int capacity;
  final String boxName;
  final MemoryTranslationCache _memory;

  Box<dynamic>? _box;

  /// Opens (or reuses) the backing Hive box and hydrates the hot layer.
  /// Safe to call multiple times.
  Future<void> open() async {
    if (_box != null) return;
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    final box = Hive.box(boxName);
    _box = box;
    for (final entry in box.toMap().entries) {
      final decoded = jsonDecode(entry.value as String) as Map<String, dynamic>;
      await _memory.put(entry.key, TranslationResult.fromJson(decoded));
    }
  }

  @override
  Future<TranslationResult?> get(String key) async {
    await open();
    final cached = await _memory.get(key);
    if (cached != null) return cached;
    final raw = _box!.get(key);
    if (raw == null) return null;
    final result =
        TranslationResult.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
    await _memory.put(key, result);
    return result;
  }

  @override
  Future<void> put(String key, TranslationResult result) async {
    await open();
    await _memory.put(key, result);
    await _box!.put(key, jsonEncode(result.toJson()));
  }

  @override
  Future<void> remove(String key) async {
    await open();
    await _memory.remove(key);
    await _box!.delete(key);
  }

  @override
  Future<void> clear() async {
    await _memory.clear();
    if (_box != null) await _box!.clear();
  }

  @override
  Future<int> get length async {
    await open();
    return _memory.length;
  }
}
