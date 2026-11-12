import 'dart:async';

import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/catalog.dart';
import '../data/downloads.dart';
import '../data/models.dart';
import '../data/prefs.dart';

enum RepeatOption { off, one, all }

/// The app's single audio player.
///
/// The queue is managed here rather than with a playlist audio source: one
/// recording is loaded at a time and the next is loaded on completion. That
/// keeps this file independent of the playlist APIs, which have churned
/// between just_audio majors, and makes the repeat rules explicit.
class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get raw => _player;

  List<Recording> _queue = const [];
  int _index = -1;

  Recording? get current =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index] : null;

  bool get isPlaying => _player.playing;
  bool get hasNext => _index >= 0 && _index < _queue.length - 1;
  bool get hasPrevious => _index > 0;

  Duration get position => _player.position;
  Duration get duration => _player.duration ?? current?.duration ?? Duration.zero;

  RepeatOption _repeat = RepeatOption.off;
  RepeatOption get repeat => _repeat;

  double get speed => _player.speed;

  Timer? _sleepTimer;
  DateTime? _sleepAt;
  DateTime? get sleepAt => _sleepAt;

  Timer? _saveTimer;
  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  /// Lets a screen ask for a rebuild after changing state this service exposes
  /// but does not own, such as a bookmark.
  void refresh() => notifyListeners();

  Future<void> init() async {
    _repeat = RepeatOption.values[Prefs.instance.repeatMode.clamp(0, 2)];
    await _player.setSpeed(Prefs.instance.speed);

    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) _onCompleted();
      notifyListeners();
    });
    _player.positionStream.listen((_) => notifyListeners());

    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persist());
  }

  /// The queue is whichever section the listener is browsing, so "next" moves
  /// through what they can see rather than through the whole catalogue.
  void setQueue(List<Recording> recordings) {
    _queue = recordings;
    final cur = current;
    _index = cur == null ? -1 : _queue.indexWhere((r) => r.id == cur.id);
    notifyListeners();
  }

  var _askedForNotifications = false;

  /// Android 13+ makes POST_NOTIFICATIONS a runtime permission. Without it the
  /// media notification cannot be posted, which means no lock-screen controls
  /// and no foreground service — so playback can be killed in the background.
  /// Asked on first play rather than at launch, so the prompt has a reason the
  /// listener can see.
  Future<void> _ensureNotificationPermission() async {
    if (_askedForNotifications || !Platform.isAndroid) return;
    _askedForNotifications = true;
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('notification permission request failed: $e');
    }
  }

  Future<void> play(Recording rec, {Duration? from, List<Recording>? queue}) async {
    await _ensureNotificationPermission();
    if (queue != null) _queue = queue;

    var idx = _queue.indexWhere((r) => r.id == rec.id);
    if (idx < 0) {
      _queue = [..._queue, rec];
      idx = _queue.length - 1;
    }

    _index = idx;
    _loading = true;
    _error = null;
    notifyListeners();

    final uri = Downloads.instance.sourceFor(rec);

    try {
      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: rec.id,
            album: Catalog.instance.reciter.ar,
            title: rec.title,
            artist: Catalog.instance.reciter.ar,
            duration: rec.duration,
            artUri: Catalog.artUri,
          ),
        ),
        initialPosition: from ?? Prefs.instance.positionFor(rec.id),
      );
      await Prefs.instance.setLastRecordingId(rec.id);
      await _player.play();
    } catch (e) {
      _error = 'تعذّر التشغيل. تحقّق من الاتصال بالإنترنت.';
      if (kDebugMode) debugPrint('play failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
      await _persist();
    } else if (current == null && _queue.isNotEmpty) {
      await play(_queue.first);
    } else {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (hasNext) await play(_queue[_index + 1], from: Duration.zero);
  }

  Future<void> previous() async {
    // Mirrors every music player: restart the track first, then step back.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else if (hasPrevious) {
      await play(_queue[_index - 1], from: Duration.zero);
    }
  }

  Future<void> seek(Duration d) async {
    await _player.seek(d < Duration.zero ? Duration.zero : d);
    await _persist();
  }

  Future<void> skip(Duration by) => seek(_player.position + by);

  Future<void> setSpeed(double v) async {
    await _player.setSpeed(v);
    await Prefs.instance.setSpeed(v);
    notifyListeners();
  }

  Future<void> setRepeat(RepeatOption m) async {
    _repeat = m;
    await Prefs.instance.setRepeatMode(m.index);
    notifyListeners();
  }

  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    if (d == null) {
      _sleepTimer = null;
      _sleepAt = null;
    } else {
      _sleepAt = DateTime.now().add(d);
      _sleepTimer = Timer(d, () async {
        await _player.pause();
        _sleepAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> _onCompleted() async {
    final rec = current;
    if (rec != null) await Prefs.instance.clearPositionFor(rec.id);

    switch (_repeat) {
      case RepeatOption.one:
        if (rec != null) await play(rec, from: Duration.zero);
      case RepeatOption.all:
        if (hasNext) {
          await next();
        } else if (_queue.isNotEmpty) {
          await play(_queue.first, from: Duration.zero);
        }
      case RepeatOption.off:
        if (hasNext) {
          await next();
        } else {
          await _player.pause();
          await _player.seek(Duration.zero);
        }
    }
  }

  Future<void> _persist() async {
    final rec = current;
    if (rec == null) return;
    final pos = _player.position;
    final d = duration;
    // Don't save a position right at the end; it would make resume useless.
    final keep = d == Duration.zero || pos < d - const Duration(seconds: 10);
    await Prefs.instance.savePositionFor(rec.id, keep ? pos : Duration.zero);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
