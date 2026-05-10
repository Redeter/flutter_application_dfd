import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/note_item.dart';
import '../services/notes_storage.dart';
import '../theme/app_colors.dart';
import '../theme/peach_app_bar.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cream_background_decor.dart';
import 'calendar_screen.dart';
import 'goals_screen.dart';
import 'note_edit_screen.dart';
import 'state_categories_sheet.dart';
import 'statistics_screen.dart';
import 'user_profile_screen.dart';

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
  const NotesScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  List<NoteItem> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Вызывается из [AppShell] при переключении на вкладку: данные могли измениться
  /// на другой вкладке (генерация статистики и т.д.), пока список был offstage.
  void reloadFromShell() => _load();

  Future<void> _load() async {
    final list = await NotesStorage.instance.loadAll();
    if (mounted) setState(() => _notes = list);
  }

  void _onBottomTab(BottomNavTab tab) {
    if (widget.embeddedInShell) return;
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
            builder: (_) => const GoalsScreen(),
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
          initialSticker: note?.sticker,
          allowDelete: note != null && index != null,
        ),
      ),
    );
    if (!mounted || result == null) return;

    if (result['deleted'] == true) {
      if (index != null && index >= 0 && index < _notes.length) {
        setState(() => _notes.removeAt(index));
        await NotesStorage.instance.saveAll(_notes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заметка удалена')),
        );
      }
      return;
    }

    final title = (result['title'] as String?)?.trim();
    final body = (result['body'] as String?)?.trim();
    final tagsRaw = (result['tags'] as String?)?.trim() ?? '';
    final date = result['date'] as DateTime? ?? DateTime.now();
    final sticker = result['sticker'] is NoteStickerKind
        ? result['sticker'] as NoteStickerKind
        : NoteStickerKind.sun;

    final manualTags = tagsRaw
        .split(RegExp(r'\s+'))
        .map((e) => e.replaceFirst('#', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final autoTags = _suggestTags(
      title: title ?? '',
      body: body ?? '',
    );
    final tagList = _normalizeTags([...manualTags, ...autoTags]);

    final normalizedTitle =
        (title != null && title.isNotEmpty) ? title : 'Заголовок';
    final normalizedBody = (body != null && body.isNotEmpty) ? body : 'Текст заметки';

    final item = NoteItem(
      date: date,
      title: normalizedTitle,
      tags: tagList,
      preview: normalizedBody,
      sticker: sticker,
    );
    setState(() {
      if (index != null && index >= 0 && index < _notes.length) {
        _notes[index] = item;
      } else {
        _notes.insert(0, item);
      }
    });
    await NotesStorage.instance.saveAll(_notes);
    if (!mounted) return;
    final summary = _buildAutoSummary(normalizedBody);
    final tagsLine = tagList.isEmpty ? 'без авто-тегов' : '#${tagList.take(3).join(' #')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Кратко: $summary • $tagsLine'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<String> _normalizeTags(List<String> tags) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in tags) {
      final normalized = raw
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-zа-яё0-9_-]', caseSensitive: false), '')
          .trim();
      if (normalized.isEmpty || normalized.length < 2) continue;
      if (seen.add(normalized)) out.add(normalized);
    }
    return out;
  }

  List<String> _suggestTags({
    required String title,
    required String body,
  }) {
    final text = '$title $body'.toLowerCase();
    final tags = <String>[];
    final map = <String, List<String>>{
      'сон': ['сон', 'бессон', 'уснул', 'проснул', 'кошмар'],
      'стресс': ['стресс', 'тревог', 'напряж', 'паник', 'выгор'],
      'работа': ['работ', 'офис', 'коллег', 'дедлайн', 'проект'],
      'учеба': ['учеб', 'экзам', 'лекц', 'курс', 'дз'],
      'отношения': ['отнош', 'семья', 'партнер', 'друз', 'конфликт'],
      'здоровье': ['болит', 'врач', 'лечение', 'симптом', 'самочув'],
      'энергия': ['устал', 'энерг', 'бодр', 'вымот', 'сил'],
      'настроение': ['радост', 'груст', 'апат', 'злость', 'настроен'],
    };
    for (final entry in map.entries) {
      final hit = entry.value.any((token) => text.contains(token));
      if (hit) tags.add(entry.key);
    }
    return tags.take(4).toList();
  }

  String _buildAutoSummary(String body) {
    final cleaned = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return 'короткая запись';
    final firstSentence = cleaned.split(RegExp(r'[.!?]')).first.trim();
    if (firstSentence.isEmpty) return 'короткая запись';
    if (firstSentence.length <= 72) return firstSentence;
    return '${firstSentence.substring(0, 72).trimRight()}...';
  }

  Future<void> _deleteNote(int index) async {
    if (index < 0 || index >= _notes.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dialogPrimary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _notes.removeAt(index));
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

  Widget _buildEmptyNotes() {
    return Center(
      child: Text(
        'Нет заметок',
        style: GoogleFonts.alegreyaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = _grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.headerPeach,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: kPeachAppBarToolbarHeight,
        actionsPadding: kPeachAppBarActionsPadding,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        title: Text(
          'Заметки',
          style: peachAppBarTitleStyle(),
        ),
        actions: [
          IconButton(
            style: peachAppBarCircleIconButtonStyle(),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Профиль',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const UserProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CreamBackgroundDecor(),
            SafeArea(
              top: false,
              bottom: false,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.orange,
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (keys.isEmpty) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: _buildEmptyNotes(),
                            ),
                          );
                        }
                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                    child: Dismissible(
                                      key: ValueKey(
                                        '${e.value.date.toIso8601String()}-${e.value.title}-$globalIndex',
                                      ),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      confirmDismiss: (_) async {
                                        await _deleteNote(globalIndex);
                                        return false;
                                      },
                                      child: _NoteCard(
                                        note: e.value,
                                        onEdit: () => _openEditor(
                                          note: e.value,
                                          index: globalIndex,
                                        ),
                                        onDelete: () => _deleteNote(globalIndex),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
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
      bottomNavigationBar: widget.embeddedInShell
          ? null
          : AppBottomNavBar(
              activeTab: BottomNavTab.notes,
              onTabSelected: _onBottomTab,
              onCenterTap: () => showStateCategoriesSheet(context),
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

class _NoteStickerGlyph extends StatelessWidget {
  const _NoteStickerGlyph({required this.kind});

  final NoteStickerKind kind;

  @override
  Widget build(BuildContext context) {
    final svg = SvgPicture.asset(kind.assetPath, fit: BoxFit.contain);
    final s = kind.glyphVisualScale;
    if (s == 1.0) return svg;
    return Transform.scale(scale: s, alignment: Alignment.center, child: svg);
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final NoteItem note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 12, top: 1),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: _NoteStickerGlyph(kind: note.sticker),
                            ),
                          ),
                          Expanded(
                            child: Text(
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
                          ),
                        ],
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
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
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
