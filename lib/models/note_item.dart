class NoteItem {
  const NoteItem({
    required this.date,
    required this.title,
    required this.tags,
    required this.preview,
  });

  final DateTime date;
  final String title;
  final List<String> tags;
  final String preview;
}
