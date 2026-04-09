import 'dart:convert';
import 'dart:developer';

import 'package:web/web.dart' as web;

import '../models/history_entry.dart';

/// The localStorage key used to persist generation history.
/// Exposed so tests can reference the same key without duplicating the string.
const kHistoryStorageKey = 'aiblojka_history';

/// Maximum number of entries kept by count. In practice the localStorage
/// quota (~5 MB) is hit before this limit when storing full-size base64
/// images — quota-based eviction in [HistoryService.save] handles that case.
const _kHistoryLimit = 10;

/// Persists the last [_kHistoryLimit] generation results in localStorage.
class HistoryService {
  /// Reads all stored entries. Returns them newest-first.
  /// Returns an empty list if storage is empty or the stored JSON is corrupt.
  List<HistoryEntry> loadAll() {
    final raw = web.window.localStorage.getItem(kHistoryStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(HistoryEntry.fromJson)
          .toList();
    } on Object {
      // Corrupt data — treat as empty rather than crashing.
      return [];
    }
  }

  /// Prepends [entry] to the stored list, evicting the oldest if at capacity.
  ///
  /// If the payload exceeds the localStorage quota, evicts the oldest entries
  /// one by one until the data fits — preserving as much history as possible.
  void save(HistoryEntry entry) {
    var entries = loadAll();
    if (entries.length >= _kHistoryLimit) {
      entries.removeLast();
    }
    entries.insert(0, entry);

    while (entries.isNotEmpty) {
      try {
        persistEntries(entries);
        return;
      } on Object catch (e) {
        // QuotaExceededError — evict the oldest entry and retry.
        log(
          'HistoryService: quota exceeded with ${entries.length} entries, evicting oldest: $e',
          name: 'HistoryService',
        );
        entries = entries.sublist(0, entries.length - 1);
      }
    }
    // Even a single entry did not fit — clear stale data.
    log('HistoryService: single entry exceeds quota, clearing storage', name: 'HistoryService');
    web.window.localStorage.removeItem(kHistoryStorageKey);
  }

  /// Removes all history entries from localStorage.
  void clear() {
    web.window.localStorage.removeItem(kHistoryStorageKey);
  }

  /// Writes [entries] to localStorage. Throws if storage quota is exceeded.
  ///
  /// Extracted as a non-private method so tests can override it to simulate
  /// [QuotaExceededError] without filling real storage.
  void persistEntries(List<HistoryEntry> entries) {
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    web.window.localStorage.setItem(kHistoryStorageKey, json);
  }
}
