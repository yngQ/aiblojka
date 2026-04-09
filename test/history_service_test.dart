@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:aiblojka/core/models/history_entry.dart';
import 'package:aiblojka/core/services/history_service.dart';

/// Simulates a localStorage quota by throwing when the list exceeds
/// [maxAllowed] entries. Writes through to real storage on success so
/// that [loadAll] can read back what was actually persisted.
class _QuotaHistoryService extends HistoryService {
  _QuotaHistoryService(this.maxAllowed);

  final int maxAllowed;

  @override
  void persistEntries(List<HistoryEntry> entries) {
    if (entries.length > maxAllowed) {
      throw Exception('QuotaExceededError');
    }
    super.persistEntries(entries);
  }
}

HistoryEntry _entry({
  String imageBase64 = 'aGVsbG8=',
  String mimeType = 'image/png',
  String format = 'long',
  String prompt = 'test prompt',
  String? style,
}) =>
    HistoryEntry(
      imageBase64: imageBase64,
      mimeType: mimeType,
      format: format,
      prompt: prompt,
      style: style,
      createdAt: DateTime(2024),
    );

void main() {
  late HistoryService service;

  setUp(() {
    web.window.localStorage.removeItem(kHistoryStorageKey);
    service = HistoryService();
  });

  group('HistoryService', () {
    test('loadAll returns empty list when storage is empty', () {
      expect(service.loadAll(), isEmpty);
    });

    test('save and loadAll round-trip a single entry', () {
      final e = _entry(prompt: 'sunset');
      service.save(e);

      final loaded = service.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.prompt, 'sunset');
      expect(loaded.first.imageBase64, 'aGVsbG8=');
      expect(loaded.first.format, 'long');
      expect(loaded.first.mimeType, 'image/png');
    });

    test('save prepends newest entry first', () {
      service.save(_entry(prompt: 'first'));
      service.save(_entry(prompt: 'second'));

      final loaded = service.loadAll();
      expect(loaded.first.prompt, 'second');
      expect(loaded.last.prompt, 'first');
    });

    test('save trims history to 10 entries', () {
      for (var i = 0; i < 12; i++) {
        service.save(_entry(prompt: 'entry $i'));
      }

      expect(service.loadAll(), hasLength(10));
    });

    test('clear removes all entries', () {
      service.save(_entry());
      service.clear();

      expect(service.loadAll(), isEmpty);
    });

    test('loadAll returns empty list on corrupt JSON', () {
      web.window.localStorage.setItem(kHistoryStorageKey, 'not valid json {{');

      expect(service.loadAll(), isEmpty);
    });

    test('fromJson tolerates missing prompt field (legacy entries)', () {
      // Simulate a localStorage entry without the prompt key.
      web.window.localStorage.setItem(
        kHistoryStorageKey,
        '[{"imageBase64":"aGVsbG8=","mimeType":"image/png","format":"long","style":null,"createdAt":"2024-01-01T00:00:00.000"}]',
      );

      final loaded = service.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.prompt, '');
    });
  });

  group('HistoryService quota eviction', () {
    test('newest entry is preserved when combined payload exceeds quota', () {
      final quota1 = _QuotaHistoryService(1);

      quota1.save(_entry(prompt: 'old'));
      quota1.save(_entry(prompt: 'new'));

      final loaded = quota1.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.prompt, 'new');
    });

    test('keeps as many entries as quota allows, newest first', () {
      final quota2 = _QuotaHistoryService(2);

      quota2.save(_entry(prompt: 'first'));
      quota2.save(_entry(prompt: 'second'));
      quota2.save(_entry(prompt: 'third'));

      final loaded = quota2.loadAll();
      expect(loaded, hasLength(2));
      expect(loaded[0].prompt, 'third');
      expect(loaded[1].prompt, 'second');
    });

    test('clears storage when even a single entry exceeds quota', () {
      final quota0 = _QuotaHistoryService(0);

      quota0.save(_entry(prompt: 'any'));

      expect(quota0.loadAll(), isEmpty);
    });
  });
}
