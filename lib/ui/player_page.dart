import 'package:material_ui/material_ui.dart';

import '../data/catalog.dart';
import '../data/downloads.dart';
import '../data/models.dart';
import '../data/prefs.dart';
import '../player/player.dart';
import 'widgets.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([player, Downloads.instance]),
      builder: (context, _) {
        final rec = player.current;
        if (rec == null) return const Scaffold(body: SizedBox.shrink());

        final t = Theme.of(context);
        final cat = Catalog.instance;
        final sid = rec.surahId;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'إغلاق',
            ),
            title: Text(cat.reciter.ar, style: t.textTheme.bodyMedium),
            actions: [
              IconButton(
                icon: Icon(Prefs.instance.isBookmarked(rec.id)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded),
                tooltip: 'حفظ في المفضّلة',
                onPressed: () async {
                  await Prefs.instance.toggleBookmark(rec.id);
                  player.refresh();
                },
              ),
              DownloadButton(recording: rec),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                _Artwork(surahId: sid),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    rec.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleLarge
                        ?.copyWith(fontSize: rec.isWholeSurah ? 32 : 23),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle(rec, cat),
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: t.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (Downloads.instance.isDownloaded(rec.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_done_rounded,
                            size: 15, color: t.colorScheme.primary),
                        const SizedBox(width: 5),
                        Text('متاحة دون إنترنت',
                            style: t.textTheme.bodySmall
                                ?.copyWith(color: t.colorScheme.primary)),
                      ],
                    ),
                  ),
                const Spacer(),
                if (player.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(player.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.colorScheme.error)),
                  ),
                const _Scrubber(),
                const SizedBox(height: 8),
                const _MainControls(),
                const SizedBox(height: 10),
                const _SecondaryControls(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _subtitle(Recording rec, Catalog cat) {
    final sid = rec.surahId;
    if (rec.isWholeSurah && sid != null) {
      final s = cat.surah(sid);
      return '${s.place} · ${Surah.arabicDigits(s.ayahs)} آية';
    }
    if (sid != null) return 'من سورة ${cat.surah(sid).ar}';
    return cat.reciter.riwaya;
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.surahId});
  final int? surahId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.colorScheme.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: t.colorScheme.secondary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Center(
        child: surahId != null
            ? Transform.scale(
                scale: 2.4,
                child: SurahMedallion(number: surahId!, active: true),
              )
            : Icon(Icons.auto_awesome_outlined,
                size: 58, color: t.colorScheme.secondary),
      ),
    );
  }
}

class _Scrubber extends StatefulWidget {
  const _Scrubber();

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    final t = Theme.of(context);
    final total = player.duration.inMilliseconds.toDouble();
    final current = _dragValue ?? player.position.inMilliseconds.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Slider(
            value: total == 0 ? 0 : current.clamp(0, total),
            max: total == 0 ? 1 : total,
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              player.seek(Duration(milliseconds: v.round()));
              setState(() => _dragValue = null);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmtDuration(Duration(milliseconds: current.round())),
                    style: t.textTheme.bodySmall),
                Text(fmtDuration(player.duration), style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainControls extends StatelessWidget {
  const _MainControls();

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 30,
          onPressed: player.hasPrevious ? player.previous : null,
          icon: const Icon(Icons.skip_previous_rounded),
          tooltip: 'السابق',
        ),
        const SizedBox(width: 6),
        IconButton(
          iconSize: 28,
          onPressed: () => player.skip(const Duration(seconds: -10)),
          icon: const Icon(Icons.replay_10_rounded),
          tooltip: '١٠ ثوانٍ للخلف',
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          height: 74,
          child: player.isLoading
              ? const Center(child: CircularProgressIndicator())
              : IconButton.filled(
                  iconSize: 40,
                  onPressed: player.toggle,
                  icon: Icon(player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  tooltip: player.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                ),
        ),
        const SizedBox(width: 10),
        IconButton(
          iconSize: 28,
          onPressed: () => player.skip(const Duration(seconds: 10)),
          icon: const Icon(Icons.forward_10_rounded),
          tooltip: '١٠ ثوانٍ للأمام',
        ),
        const SizedBox(width: 6),
        IconButton(
          iconSize: 30,
          onPressed: player.hasNext ? player.next : null,
          icon: const Icon(Icons.skip_next_rounded),
          tooltip: 'التالي',
        ),
      ],
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls();

  static const _speeds = [0.75, 1.0, 1.25, 1.5];

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    final t = Theme.of(context);

    final repeatIcon = switch (player.repeat) {
      RepeatOption.off => Icons.repeat_rounded,
      RepeatOption.one => Icons.repeat_one_rounded,
      RepeatOption.all => Icons.repeat_on_rounded,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: () {
            final i = _speeds.indexOf(player.speed);
            player.setSpeed(_speeds[(i < 0 ? 1 : i + 1) % _speeds.length]);
          },
          child: Text('${player.speed}×',
              style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: switch (player.repeat) {
            RepeatOption.off => 'بدون تكرار',
            RepeatOption.one => 'تكرار الحالي',
            RepeatOption.all => 'تكرار الكل',
          },
          onPressed: () => player.setRepeat(
            RepeatOption.values[(player.repeat.index + 1) % RepeatOption.values.length],
          ),
          icon: Icon(repeatIcon,
              color: player.repeat == RepeatOption.off ? null : t.colorScheme.primary),
        ),
        IconButton(
          tooltip: 'مؤقّت النوم',
          onPressed: () => _sleepSheet(context, player),
          icon: Icon(Icons.bedtime_outlined,
              color: player.sleepAt == null ? null : t.colorScheme.primary),
        ),
      ],
    );
  }

  Future<void> _sleepSheet(BuildContext context, PlayerService player) async {
    const options = <String, Duration?>{
      'إيقاف المؤقّت': null,
      '١٠ دقائق': Duration(minutes: 10),
      '٢٠ دقيقة': Duration(minutes: 20),
      '٣٠ دقيقة': Duration(minutes: 30),
      'ساعة واحدة': Duration(hours: 1),
    };

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in options.entries)
              ListTile(
                title: Text(e.key),
                leading: Icon(e.value == null
                    ? Icons.bedtime_off_outlined
                    : Icons.bedtime_outlined),
                onTap: () {
                  player.setSleepTimer(e.value);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
