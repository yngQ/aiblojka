@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:aiblojka/core/models/history_entry.dart';
import 'package:aiblojka/core/services/history_service.dart';

const _kStorageKey = 'aiblojka_history';

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
    web.window.localStorage.removeItem(_kStorageKey);
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
      web.window.localStorage.setItem(_kStorageKey, 'not valid json {{');

      expect(service.loadAll(), isEmpty);
    });

    test('fromJson tolerates missing prompt field (legacy entries)', () {
      // Simulate a localStorage entry without the prompt key.
      web.window.localStorage.setItem(
        _kStorageKey,
        '[{"imageBase64":"aGVsbG8=","mimeType":"image/png","format":"long","style":null,"createdAt":"2024-01-01T00:00:00.000"}]',
      );

      final loaded = service.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.prompt, '');
    });
  });
}
