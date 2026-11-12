import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

enum DownloadState { none, running, done, failed }

class DownloadInfo {
  const DownloadInfo(this.state, [this.progress = 0]);
  final DownloadState state;
  final double progress; // 0..1
}

/// Offline downloads, one file per recording.
///
/// Files are written to a `.part` path first and renamed into place only once
/// complete, so an interrupted download can never be mistaken for a good file.
/// Partial files resume with a Range request — archive.org supports them.
class Downloads extends ChangeNotifier {
  Downloads._(this._dir);
  final Directory _dir;

  static Downloads? _i;
  static Downloads get instance => _i!;

  static Future<Downloads> load() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _i = Downloads._(dir);
  }

  final Map<String, DownloadInfo> _state = {};
  final Map<String, StreamSubscription<List<int>>> _active = {};
  final _client = HttpClient();

  File fileFor(String recordingId) => File('${_dir.path}/$recordingId.mp3');

  bool isDownloaded(String recordingId) => fileFor(recordingId).existsSync();

  DownloadInfo infoFor(String recordingId) {
    if (isDownloaded(recordingId)) return const DownloadInfo(DownloadState.done, 1);
    return _state[recordingId] ?? const DownloadInfo(DownloadState.none);
  }

  /// The URI the player should use: the local file when we have it, the network
  /// otherwise. The single place that decides online vs offline.
  Uri sourceFor(Recording r) {
    final f = fileFor(r.id);
    return f.existsSync() ? f.uri : Uri.parse(r.url);
  }

  Future<void> download(Recording r) async {
    if (_active.containsKey(r.id) || isDownloaded(r.id)) return;

    final target = fileFor(r.id);
    final part = File('${target.path}.part');
    var already = await part.exists() ? await part.length() : 0;

    _state[r.id] = DownloadInfo(DownloadState.running, already / r.bytes);
    notifyListeners();

    try {
      final req = await _client.getUrl(Uri.parse(r.url));
      if (already > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$already-');
      final res = await req.close();

      // 206 = our Range was honoured. 200 = the server sent the whole file, so
      // the bytes we already had are not a prefix we can trust: start over.
      if (res.statusCode == HttpStatus.ok && already > 0) {
        already = 0;
        if (await part.exists()) await part.delete();
      } else if (res.statusCode != HttpStatus.ok &&
          res.statusCode != HttpStatus.partialContent) {
        throw HttpException('HTTP ${res.statusCode}');
      }

      final sink = part.openWrite(mode: FileMode.append);
      var received = already;
      final done = Completer<void>();

      _active[r.id] = res.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          _state[r.id] = DownloadInfo(
            DownloadState.running,
            (received / r.bytes).clamp(0.0, 1.0),
          );
          notifyListeners();
        },
        onDone: () async {
          await sink.close();
          await part.rename(target.path);
          done.complete();
        },
        onError: (Object e) async {
          await sink.close();
          done.completeError(e);
        },
        cancelOnError: true,
      );

      await done.future;
      _state[r.id] = const DownloadInfo(DownloadState.done, 1);
    } catch (_) {
      _state[r.id] = const DownloadInfo(DownloadState.failed);
    } finally {
      _active.remove(r.id);
      notifyListeners();
    }
  }

  Future<void> cancel(String recordingId) async {
    await _active.remove(recordingId)?.cancel();
    _state[recordingId] = const DownloadInfo(DownloadState.none);
    notifyListeners();
  }

  Future<void> delete(String recordingId) async {
    await cancel(recordingId);
    final f = fileFor(recordingId);
    if (await f.exists()) await f.delete();
    final p = File('${f.path}.part');
    if (await p.exists()) await p.delete();
    _state.remove(recordingId);
    notifyListeners();
  }

  int get downloadedBytes {
    var total = 0;
    for (final f in _dir.listSync()) {
      if (f is File && f.path.endsWith('.mp3')) total += f.lengthSync();
    }
    return total;
  }

  Future<void> deleteAll() async {
    for (final f in _dir.listSync()) {
      if (f is File) await f.delete();
    }
    _state.clear();
    notifyListeners();
  }
}
