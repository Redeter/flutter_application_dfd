import 'dart:convert';

import '../models/note_item.dart';
import 'firestore_repository.dart';
import 'secure_kv_service.dart';
import 'user_scoped_store.dart';

const _keyNotes = 'notes';

class NotesStorage {
  NotesStorage._();
  static NotesStorage get instance => _instance;
  static final _instance = NotesStorage._();

  List<NoteItem> _parseList(List<dynamic>? list) {
    if (list == null) return [];
    return list
        .map((e) {
          final m = e as Map<String, dynamic>?;
          if (m == null) return null;
          final date = DateTime.tryParse(m['date'] as String? ?? '');
          if (date == null) return null;
          return NoteItem(
            date: date,
            title: m['title'] as String? ?? '',
            tags:
                (m['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            preview: m['preview'] as String? ?? '',
            sticker: NoteStickerKind.fromStorage(m['sticker'] as String?),
          );
        })
        .whereType<NoteItem>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<NoteItem>> loadAll() async {
    final cloud = await FirestoreRepository.instance
        .loadJsonList(FirestoreRepository.fieldNotes);
    if (cloud != null) {
      return _parseList(cloud);
    }

    final key = await UserScopedStore.scopedKey(_keyNotes);
    final raw = await SecureKvService.instance.readString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      return _parseList(jsonDecode(raw) as List<dynamic>?);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<NoteItem> notes) async {
    final encoded = notes
        .map((n) => {
              'date': n.date.toIso8601String(),
              'title': n.title,
              'tags': n.tags,
              'preview': n.preview,
              'sticker': n.sticker.storageKey,
            })
        .toList();

    await FirestoreRepository.instance.saveJsonList(
      FirestoreRepository.fieldNotes,
      encoded.cast<Map<String, dynamic>>(),
    );

    final key = await UserScopedStore.scopedKey(_keyNotes);
    await SecureKvService.instance.writeString(key, jsonEncode(encoded));
  }
}
