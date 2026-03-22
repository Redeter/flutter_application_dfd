import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note_item.dart';

const _keyNotes = 'notes';

class NotesStorage {
  NotesStorage._();
  static NotesStorage get instance => _instance;
  static final _instance = NotesStorage._();

  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<NoteItem>> loadAll() async {
    await _init();
    final raw = _prefs!.getString(_keyNotes);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>?;
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
              tags: (m['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              preview: m['preview'] as String? ?? '',
            );
          })
          .whereType<NoteItem>()
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<NoteItem> notes) async {
    await _init();
    final encoded = jsonEncode(notes.map((n) => {
          'date': n.date.toIso8601String(),
          'title': n.title,
          'tags': n.tags,
          'preview': n.preview,
        }).toList());
    await _prefs!.setString(_keyNotes, encoded);
  }
}
