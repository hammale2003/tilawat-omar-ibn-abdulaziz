import 'package:material_ui/material_ui.dart';

import '../data/catalog.dart';
import '../data/downloads.dart';
import '../data/models.dart';
import '../data/prefs.dart';
import '../player/player.dart';
import 'mini_player.dart';
import 'player_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  String _query = '';
  late String _section = Prefs.instance.section;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Strips harakat and unifies alif/ya/ta-marbuta so that searching for
  /// "الاخلاص" finds "الإخلاص".
  static String _normalise(String s) => s
      .replaceAll(RegExp(r'[ً-ْـ]'), '')
      .replaceAll(RegExp(r'[إأآا]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  List<Recording> get _visible {
    final cat = Catalog.instance;
    var list = cat.inSection(_section);

    final q = _query.trim();
    if (q.isEmpty) return list;

    final norm = _normalise(q);
    return list.where((r) {
      if (_normalise(r.title).contains(norm)) return true;
      final sid = r.surahId;
      if (sid != null) {
        final s = cat.surah(sid);
        if (_normalise(s.ar).contains(norm)) return true;
        if (s.en.toLowerCase().contains(q.toLowerCase())) return true;
        if (sid.toString() == q || Surah.arabicDigits(sid) == q) return true;
      }
      return false;
    }).toList();
  }

  void _selectSection(String id) {
    setState(() => _section = id);
    Prefs.instance.setSection(id);
    PlayerService.instance.setQueue(Catalog.instance.inSection(id));
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    final cat = Catalog.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([player, Downloads.instance]),
      builder: (context, _) {
        final items = _visible;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  reciter: cat.reciter,
                  onSettings: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SettingsPage()))
                      .then((_) => setState(() {})),
                ),
                _SectionTabs(
                  sections: cat.sections,
                  selected: _section,
                  countFor: (id) => cat.inSection(id).length,
                  onSelect: _selectSection,
                ),
                _SearchBar(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                          itemCount: items.length + 1,
                          separatorBuilder: (_, i) =>
                              i == 0 ? const SizedBox.shrink() : const Divider(indent: 70),
                          itemBuilder: (context, i) => i == 0
                              ? const _ContinueCard()
                              : _RecordingTile(
                                  recording: items[i - 1],
                                  queue: items,
                                ),
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const MiniPlayer(),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.reciter, required this.onSettings});
  final ReciterInfo reciter;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تلاوات',
                    style: t.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: t.colorScheme.primary,
                    )),
                const SizedBox(height: 2),
                Text(
                  '${reciter.ar} — ${reciter.riwaya}',
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.sections,
    required this.selected,
    required this.countFor,
    required this.onSelect,
  });

  final List<Section> sections;
  final String selected;
  final int Function(String) countFor;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = sections[i];
          return ChoiceChip(
            label: Text('${s.ar}  ${Surah.arabicDigits(countFor(s.id))}'),
            selected: s.id == selected,
            onSelected: (_) => onSelect(s.id),
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث عن سورة أو تلاوة',
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 19),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: t.colorScheme.onSurface.withValues(alpha: 0.045),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// "Continue where you left off" — the most-used control in a listening app,
/// so it sits above the list rather than inside it.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context) {
    final id = Prefs.instance.lastRecordingId;
    if (id == null) return const SizedBox.shrink();

    final rec = Catalog.instance.byId(id);
    if (rec == null) return const SizedBox.shrink();

    final pos = Prefs.instance.positionFor(id);
    if (pos < const Duration(seconds: 20)) return const SizedBox.shrink();

    final t = Theme.of(context);
    final progress = pos.inMilliseconds / rec.duration.inMilliseconds.clamp(1, 1 << 30);

    return Card(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          PlayerService.instance.play(rec, from: pos);
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const PlayerPage()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: t.colorScheme.primary,
                child: Icon(Icons.play_arrow_rounded,
                    color: t.colorScheme.onPrimary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('متابعة الاستماع',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurface.withValues(alpha: 0.6),
                        )),
                    const SizedBox(height: 3),
                    Text(rec.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor:
                            t.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording, required this.queue});
  final Recording recording;
  final List<Recording> queue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final player = PlayerService.instance;
    final cat = Catalog.instance;
    final isCurrent = player.current?.id == recording.id;
    final sid = recording.surahId;

    final subtitle = StringBuffer();
    if (recording.isWholeSurah && sid != null) {
      final s = cat.surah(sid);
      subtitle.write('${s.place} · ${Surah.arabicDigits(s.ayahs)} آية · ');
    } else if (sid != null) {
      subtitle.write('من سورة ${cat.surah(sid).ar} · ');
    }
    subtitle.write(fmtDuration(recording.duration));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: sid != null
          ? SurahMedallion(number: sid, active: isCurrent)
          : SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.auto_awesome_outlined,
                  color: isCurrent
                      ? t.colorScheme.primary
                      : t.colorScheme.secondary.withValues(alpha: 0.7)),
            ),
      title: Text(
        recording.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: t.textTheme.titleMedium?.copyWith(
          fontSize: recording.isWholeSurah ? 21 : 17,
          color: isCurrent ? t.colorScheme.primary : null,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle.toString(),
          style: t.textTheme.bodySmall?.copyWith(
            color: t.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
      trailing: DownloadButton(recording: recording),
      onTap: () {
        player.play(recording, queue: queue);
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const PlayerPage()));
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: t.colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 14),
            Text('لا توجد نتائج',
                style: t.textTheme.titleMedium?.copyWith(
                  color: t.colorScheme.onSurface.withValues(alpha: 0.6),
                )),
          ],
        ),
      ),
    );
  }
}
