import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app remembers between launches.
///
/// Nothing here ever leaves the device. The app has no backend, no analytics
/// and no accounts — this is the whole of its persistent state.
class Prefs {
  Prefs._(this._p);
  final SharedPreferences _p;

  static Prefs? _i;
  static Prefs get instance => _i!;

  static Future<Prefs> load() async =>
      _i = Prefs._(await SharedPreferences.getInstance());

  // --- resume: the last thing played ---
  static const _kLast = 'last_recording';
  String? get lastRecordingId => _p.getString(_kLast);
  Future<void> setLastRecordingId(String id) => _p.setString(_kLast, id);

  /// Per-recording position, so returning to a long surah picks up where you
  /// left off rather than at the beginning.
  Duration positionFor(String recordingId) =>
      Duration(milliseconds: _p.getInt('pos_$recordingId') ?? 0);

  Future<void> savePositionFor(String recordingId, Duration pos) =>
      _p.setInt('pos_$recordingId', pos.inMilliseconds);

  Future<void> clearPositionFor(String recordingId) =>
      _p.remove('pos_$recordingId');

  // --- playback preferences ---
  double get speed => _p.getDouble('speed') ?? 1.0;
  Future<void> setSpeed(double v) => _p.setDouble('speed', v);

  int get repeatMode => _p.getInt('repeat_mode') ?? 0; // 0 off, 1 one, 2 all
  Future<void> setRepeatMode(int v) => _p.setInt('repeat_mode', v);

  String get section => _p.getString('section') ?? 'surahs';
  Future<void> setSection(String v) => _p.setString('section', v);

  // --- bookmarks ---
  static const _kBookmarks = 'bookmarks';
  List<String> get bookmarks => _p.getStringList(_kBookmarks) ?? const [];

  bool isBookmarked(String id) => bookmarks.contains(id);

  Future<void> toggleBookmark(String id) async {
    final b = [...bookmarks];
    b.contains(id) ? b.remove(id) : b.add(id);
    await _p.setStringList(_kBookmarks, b);
  }

  // --- theme ---
  int get themeMode => _p.getInt('theme_mode') ?? 0; // 0 system, 1 light, 2 dark
  Future<void> setThemeMode(int v) => _p.setInt('theme_mode', v);
}
