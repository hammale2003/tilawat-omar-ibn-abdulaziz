import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Loads the bundled surah table and the recitation catalogue.
///
/// The catalogue is deliberately a plain JSON asset: adding recordings is a
/// data edit, not a code change.
class Catalog {
  Catalog._(this.surahs, this.reciter, this.sections, this.recordings);

  final List<Surah> surahs;
  final ReciterInfo reciter;
  final List<Section> sections;
  final List<Recording> recordings;

  /// File URI of the artwork shown in the lock-screen media control.
  /// Android cannot read a Flutter asset path, so the image is written to the
  /// app's support directory once and referenced from there.
  static Uri? artUri;

  static Future<void> _prepareArtwork() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/art.png');
      if (!await f.exists()) {
        final bytes = await rootBundle.load('assets/art.png');
        await f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      }
      artUri = f.uri;
    } catch (_) {
      // Artwork is cosmetic: a failure here must not stop the app loading.
      artUri = null;
    }
  }

  static Catalog? _instance;
  static Catalog get instance {
    final c = _instance;
    if (c == null) throw StateError('Catalog.load() must be awaited before use');
    return c;
  }

  static Future<Catalog> load() async {
    final surahJson =
        jsonDecode(await rootBundle.loadString('assets/surahs.json')) as List;
    final cat = jsonDecode(await rootBundle.loadString('assets/catalog.json'))
        as Map<String, dynamic>;

    await _prepareArtwork();

    return _instance = Catalog._(
      surahJson
          .map((e) => Surah.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      ReciterInfo.fromJson(cat['reciter'] as Map<String, dynamic>),
      (cat['sections'] as List)
          .map((e) => Section.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      (cat['recordings'] as List)
          .map((e) => Recording.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Surah surah(int id) => surahs[id - 1];

  List<Recording> inSection(String sectionId) =>
      recordings.where((r) => r.section == sectionId).toList(growable: false);

  Recording? byId(String id) {
    for (final r in recordings) {
      if (r.id == id) return r;
    }
    return null;
  }

  int get totalBytes => recordings.fold(0, (a, r) => a + r.bytes);
  Duration get totalDuration =>
      Duration(seconds: recordings.fold(0, (a, r) => a + r.secs));
}
