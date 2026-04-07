import 'dart:convert';

import 'package:web/web.dart' as web;

import '../models/history_entry.dart';

const _kStorageKey = 'aiblojka_history';
const _kHistoryLimit = 10;

/// Persists the last [_kHistoryLimit] generation results in localStorage.
class HistoryService {
  /// Reads all stored entries. Returns them newest-first.
  /// Returns an empty list if storage is empty or the stored JSON is corrupt.
  List<HistoryEntry> loadAll() {
    final raw = web.window.localStorage.getItem(_kStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(HistoryEntry.fromJson)
          .toList();
    } catch (_) {
      // Corrupt data — treat as empty rather than crashing.
      return [];
    }
  }

  /// Prepends [entry] to the stored list and trims to [_kHistoryLimit].
  void save(HistoryEntry entry) {
    final entries = loadAll();
    entries.insert(0, entry);
    if (entries.length > _kHistoryLimit) {
      entries.removeRange(_kHistoryLimit, entries.length);
    }
    _persist(entries);
  }

  /// Removes all history entries from localStorage.
  void clear() {
    web.window.localStorage.removeItem(_kStorageKey);
  }

  void _persist(List<HistoryEntry> entries) {
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    web.window.localStorage.setItem(_kStorageKey, json);
  }
}
