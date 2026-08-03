import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Local cache of AI tutor responses.
///
/// Every answer is stored as its JSON encoding so repeating a lookup is
/// instant, recently asked questions still work offline, and rate-limited
/// providers are hit only once per unique request. Keys are the canonical
/// cache keys produced by `AiTutorService` (`ai|word|…`, `ai|grammar|…`,
/// `ai|tutor|…`).
abstract class AiCache {
  /// Returns the cached JSON string for [key], or `null` when absent.
  Future<String?> get(String key);

  /// Stores the JSON-encoded [value] under [key].
  Future<void> put(String key, String value);

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
/// repeat AI lookups instant within a session.
class MemoryAiCache implements AiCache {
  MemoryAiCache({this.capacity = 500})
      : assert(capacity > 0, 'capacity must be positive');

  /// Maximum number of entries kept in memory.
  final int capacity;

  final Map<String, String> _entries = {};

  /// Keys ordered oldest-first; the most recently used key sits at the end.
  final List<String> _order = [];

  @override
  Future<String?> get(String key) async {
    final value = _entries[key];
    if (value == null) return null;
    _touch(key);
    return value;
  }

  @override
  Future<void> put(String key, String value) async {
    if (_entries.containsKey(key)) {
      _entries[key] = value;
      _touch(key);
    } else {
      _entries[key] = value;
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
/// [MemoryAiCache] hot layer.
///
/// On [open] the box is hydrated into memory so that repeated lookups are
/// served instantly without disk I/O, and every write is mirrored to disk so
/// recent AI answers survive app restarts and work offline.
class HiveAiCache implements AiCache {
  HiveAiCache({
    this.capacity = 500,
    this.boxName = 'ai_cache',
  }) : _memory = MemoryAiCache(capacity: capacity);

  final int capacity;
  final String boxName;
  final MemoryAiCache _memory;

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
      await _memory.put(entry.key, entry.value as String);
    }
  }

  @override
  Future<String?> get(String key) async {
    await open();
    final cached = await _memory.get(key);
    if (cached != null) return cached;
    final raw = _box!.get(key);
    if (raw == null) return null;
    final value = raw as String;
    await _memory.put(key, value);
    return value;
  }

  @override
  Future<void> put(String key, String value) async {
    await open();
    await _memory.put(key, value);
    await _box!.put(key, value);
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
