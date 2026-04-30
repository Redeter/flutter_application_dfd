import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/note_item.dart';
import '../services/notes_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'articles_screen.dart';
import 'calendar_screen.dart';
import 'note_edit_screen.dart';
import 'state_categories_sheet.dart';
import 'statistics_screen.dart';

String _dateHeaderRu(DateTime d) {
  const months = [
    'ЯНВАРЯ',
    'ФЕВРАЛЯ',
    'МАРТА',
    'АПРЕЛЯ',
    'МАЯ',
    'ИЮНЯ',
    'ИЮЛЯ',
    'АВГУСТА',
    'СЕНТЯБРЯ',
    'ОКТЯБРЯ',
    'НОЯБРЯ',
    'ДЕКАБРЯ',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteItem> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await NotesStorage.instance.loadAll();
    if (mounted) setState(() => _notes = list);
  }

  void _onBottomTab(BottomNavTab tab) {
    switch (tab) {
      case BottomNavTab.notes:
        return;
      case BottomNavTab.statistics:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const StatisticsScreen(),
          ),
        );
      case BottomNavTab.calendar:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const CalendarScreen(),
          ),
        );
      case BottomNavTab.articles:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const ArticlesScreen(),
          ),
        );
    }
  }

  Future<void> _openEditor({NoteItem? note, int? index}) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(
          initialTitle: note?.title,
          initialBody: note?.preview,
          initialTags: note?.tags.map((e) => '#$e').join(' '),
          selectedDate: note?.date,
        ),
      ),
    );
    if (!mounted || result == null) return;

    final title = (result['title'] as String?)?.trim();
    final body = (result['body'] as String?)?.trim();
    final tagsRaw = (result['tags'] as String?)?.trim() ?? '';
    final date = result['date'] as DateTime? ?? DateTime.now();

    final tagList = tagsRaw
        .split(RegExp(r'\s+'))
        .map((e) => e.replaceFirst('#', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final item = NoteItem(
      date: date,
      title: (title != null && title.isNotEmpty) ? title : 'Заголовок',
      tags: tagList.isNotEmpty ? tagList : ['тэг1'],
      preview: (body != null && body.isNotEmpty) ? body : 'Текст заметки',
    );
    setState(() {
      if (index != null && index >= 0 && index < _notes.length) {
        _notes[index] = item;
      } else {
        _notes.insert(0, item);
      }
    });
    await NotesStorage.instance.saveAll(_notes);
  }

  Map<DateTime, List<NoteItem>> get _grouped {
    final map = <DateTime, List<NoteItem>>{};
    for (final n in _notes) {
      final key = DateTime(n.date.year, n.date.month, n.date.day);
      map.putIfAbsent(key, () => []).add(n);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final keys = _grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.peachBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: _profileAvatar(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                itemCount: keys.length,
                itemBuilder: (context, sectionIndex) {
                  final day = keys[sectionIndex];
                  final items = _grouped[day]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DateDivider(label: _dateHeaderRu(day)),
                      const SizedBox(height: 14),
                      ...items.asMap().entries.map((e) {
                        final globalIndex = _notes.indexOf(e.value);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _NoteCard(
                            note: e.value,
                            onEdit: () => _openEditor(
                              note: e.value,
                              index: globalIndex,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          elevation: 6,
          shadowColor: AppColors.orange.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _openEditor(),
            child: Ink(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange,
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: AppColors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: AppBottomNavBar(
        activeTab: BottomNavTab.notes,
        onTabSelected: _onBottomTab,
        onCenterTap: () => showStateCategoriesSheet(context),
      ),
    );
  }

  Widget _profileAvatar() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.orange, width: 4),
      ),
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.peachBackground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 16,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.peachBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            thickness: 1,
            height: 1,
            color: AppColors.orange.withValues(alpha: 0.45),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.alegreyaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textDark.withValues(alpha: 0.85),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            thickness: 1,
            height: 1,
            color: AppColors.orange.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
  });

  final NoteItem note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final normalizedTags = note.tags
        .map((t) => t.replaceFirst('#', '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE8E8ED), // iOS-like soft border
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFD1D1D6), // стикеры (placeholder)
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: normalizedTags.isEmpty
                            ? [
                                _TagPill(label: 'без тега'),
                              ]
                            : normalizedTags
                                .take(4)
                                .map((t) => _TagPill(label: t))
                                .toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.preview,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 16,
                          height: 1.35,
                          color: AppColors.textDark.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF8E8E93),
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '#$label',
        style: GoogleFonts.alegreyaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF636366),
        ),
      ),
    );
  }
}
