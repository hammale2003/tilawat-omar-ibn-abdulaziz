import 'package:material_ui/material_ui.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'data/catalog.dart';
import 'data/downloads.dart';
import 'data/prefs.dart';
import 'player/player.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Registers the background audio service: lock-screen controls, playback
  // that survives the app being backgrounded, headphone and car controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tilawa.audio',
    androidNotificationChannelName: 'التلاوات',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  await Prefs.load();
  await Downloads.load();
  await Catalog.load();

  themeModeNotifier.value = ThemeMode.values[Prefs.instance.themeMode.clamp(0, 2)];

  final player = PlayerService.instance;
  await player.init();
  player.setQueue(Catalog.instance.inSection(Prefs.instance.section));

  runApp(const TilawaApp());
}

class TilawaApp extends StatelessWidget {
  const TilawaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'تلاوات عمر بن عبد العزيز',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // The whole app is Arabic and right-to-left.
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
  }
}
