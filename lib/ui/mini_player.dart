import 'package:material_ui/material_ui.dart';

import '../player/player.dart';
import 'player_page.dart';

/// Persistent bar at the bottom. Visible only once something is playing, so an
/// untouched app has nothing in the way.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;

    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final rec = player.current;
        if (rec == null) return const SizedBox.shrink();

        final t = Theme.of(context);
        final d = player.duration;
        final progress = d.inMilliseconds == 0
            ? 0.0
            : player.position.inMilliseconds / d.inMilliseconds;

        return Material(
          color: t.colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayerPage()),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: t.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                rec.title,
                                style: t.textTheme.titleMedium?.copyWith(fontSize: 17),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${fmtDuration(player.position)} / ${fmtDuration(d)}',
                                style: t.textTheme.bodySmall?.copyWith(
                                  color: t.colorScheme.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: player.previous,
                          icon: const Icon(Icons.skip_previous_rounded),
                          tooltip: 'السابق',
                        ),
                        IconButton.filled(
                          onPressed: player.toggle,
                          icon: Icon(player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                          tooltip: player.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                        ),
                        IconButton(
                          onPressed: player.hasNext ? player.next : null,
                          icon: const Icon(Icons.skip_next_rounded),
                          tooltip: 'التالي',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
