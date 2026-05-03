/// Стикер заметки (SVG в assets/icons/notes_stickers/).
enum NoteStickerKind {
  sun,
  moon,
  star,
  cloud;

  static NoteStickerKind fromStorage(String? raw) {
    switch (raw) {
      case 'moon':
        return NoteStickerKind.moon;
      case 'star':
        return NoteStickerKind.star;
      case 'cloud':
        return NoteStickerKind.cloud;
      case 'sun':
      default:
        return NoteStickerKind.sun;
    }
  }

  String get storageKey => name;

  String get assetPath => switch (this) {
        NoteStickerKind.sun => 'assets/icons/notes_stickers/sun.svg',
        NoteStickerKind.moon => 'assets/icons/notes_stickers/moon.svg',
        NoteStickerKind.star => 'assets/icons/notes_stickers/star.svg',
        NoteStickerKind.cloud => 'assets/icons/notes_stickers/cloudy.svg',
      };

  /// Подгонка размера арта относительно холста (превью и список).
  double get glyphVisualScale => switch (this) {
        NoteStickerKind.sun => 1.0,
        NoteStickerKind.moon => 1.30,
        NoteStickerKind.star => 0.86,
        NoteStickerKind.cloud => 0.86,
      };
}

class NoteItem {
  const NoteItem({
    required this.date,
    required this.title,
    required this.tags,
    required this.preview,
    this.sticker = NoteStickerKind.sun,
  });

  final DateTime date;
  final String title;
  final List<String> tags;
  final String preview;
  final NoteStickerKind sticker;
}
