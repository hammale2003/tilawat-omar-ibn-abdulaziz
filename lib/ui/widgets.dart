import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/downloads.dart';
import '../data/models.dart';

/// The numbered medallion beside each surah — an eight-point star, the shape
/// used for ayah markers in printed masahif.
class SurahMedallion extends StatelessWidget {
  const SurahMedallion({super.key, required this.number, this.active = false});
  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colour = active ? t.colorScheme.primary : t.colorScheme.secondary;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(46, 46),
            painter: _StarPainter(
              colour.withValues(alpha: active ? 0.85 : 0.45),
              fill: active ? colour.withValues(alpha: 0.12) : null,
            ),
          ),
          Text(
            Surah.arabicDigits(number),
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: active ? t.colorScheme.primary : t.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.colour, {this.fill});
  final Color colour;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1.5;
    final path = Path();

    // Two squares, the second rotated 45°, giving an eight-pointed star.
    for (var k = 0; k < 2; k++) {
      final offset = k * math.pi / 4;
      for (var i = 0; i < 4; i++) {
        final a = offset + i * math.pi / 2;
        final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    }

    final f = fill;
    if (f != null) {
      canvas.drawPath(path, Paint()..color = f);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.colour != colour || old.fill != fill;
}

/// Download control: a tap starts or cancels, a long press deletes a saved file.
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key, required this.recording});
  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final d = Downloads.instance;
    final info = d.infoFor(recording.id);

    switch (info.state) {
      case DownloadState.done:
        return IconButton(
          tooltip: 'محفوظة — اضغط مطوّلاً للحذف',
          onPressed: () => _confirmDelete(context, d),
          icon: Icon(Icons.download_done_rounded, size: 20, color: t.colorScheme.primary),
        );
      case DownloadState.running:
        return IconButton(
          tooltip: 'إلغاء التنزيل',
          onPressed: () => d.cancel(recording.id),
          icon: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: info.progress == 0 ? null : info.progress,
              strokeWidth: 2.2,
            ),
          ),
        );
      case DownloadState.failed:
        return IconButton(
          tooltip: 'فشل التنزيل — أعد المحاولة',
          onPressed: () => d.download(recording),
          icon: Icon(Icons.refresh_rounded, size: 20, color: t.colorScheme.error),
        );
      case DownloadState.none:
        return IconButton(
          tooltip: 'تنزيل (${recording.megabytes.round()} م.ب)',
          onPressed: () => d.download(recording),
          icon: Icon(
            Icons.download_outlined,
            size: 20,
            color: t.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Downloads d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف من الجهاز؟'),
        content: const Text('يمكنك تنزيله مرة أخرى في أي وقت.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok ?? false) await d.delete(recording.id);
  }
}
