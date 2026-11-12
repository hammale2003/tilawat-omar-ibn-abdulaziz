import 'package:material_ui/material_ui.dart';

import '../data/catalog.dart';
import '../data/downloads.dart';
import '../data/models.dart';
import '../data/prefs.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cat = Catalog.instance;
    final downloads = Downloads.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _section(context, 'القارئ'),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: Text(cat.reciter.ar,
                style: t.textTheme.titleMedium?.copyWith(fontSize: 19)),
            subtitle: Text(
              '${cat.reciter.riwaya} · '
              '${Surah.arabicDigits(cat.recordings.length)} تسجيلاً · '
              '${Surah.arabicDigits(cat.totalDuration.inHours)} ساعة',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'لم يُنشر للشيخ مصحف كامل حتى الآن. يجمع التطبيق كل ما هو متاح من '
              'تلاواته: السور المسجّلة كاملة، ومقتطفات من صلوات التراويح والتهجّد، '
              'والرقية الشرعية وآيات السكينة. وتُضاف التسجيلات الجديدة فور توفّرها.',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.7,
              ),
            ),
          ),

          const Divider(),
          _section(context, 'المحتوى'),
          for (final s in cat.sections)
            ListTile(
              dense: true,
              leading: const Icon(Icons.library_music_outlined, size: 20),
              title: Text(s.ar),
              subtitle: s.note.isEmpty ? null : Text(s.note),
              trailing: Text(Surah.arabicDigits(cat.inSection(s.id).length),
                  style: t.textTheme.titleMedium),
            ),

          const Divider(),
          _section(context, 'المظهر'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('تلقائي')),
                  ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('داكن')),
                ],
                selected: {mode},
                onSelectionChanged: (s) async {
                  themeModeNotifier.value = s.first;
                  await Prefs.instance.setThemeMode(s.first.index);
                },
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),
          _section(context, 'التخزين'),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('الملفات المحفوظة'),
            subtitle: Text('${(downloads.downloadedBytes / 1e6).round()} م.ب'),
            trailing: TextButton(
              onPressed: downloads.downloadedBytes == 0
                  ? null
                  : () async {
                      if (await _confirm(context)) {
                        await downloads.deleteAll();
                        if (context.mounted) setState(() {});
                      }
                    },
              child: const Text('حذف الكل'),
            ),
          ),

          const Divider(),
          _section(context, 'عن التطبيق'),
          const ListTile(
            leading: Icon(Icons.lock_outline_rounded),
            title: Text('لا يجمع التطبيق أي بيانات'),
            subtitle: Text(
                'بدون حسابات، بدون إعلانات، وبدون تتبّع. كل شيء يبقى على جهازك.'),
          ),
          ListTile(
            leading: const Icon(Icons.audiotrack_outlined),
            title: const Text('مصدر التلاوات'),
            subtitle: Text(cat.reciter.source),
          ),
          const ListTile(
            leading: Icon(Icons.font_download_outlined),
            title: Text('الخطوط'),
            subtitle: Text('Amiri و Tajawal — رخصة SIL Open Font License'),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Future<bool> _confirm(BuildContext context) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف كل الملفات المحفوظة؟'),
        content: const Text('ستحتاج إلى الإنترنت للاستماع مرة أخرى.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    return r ?? false;
  }
}
