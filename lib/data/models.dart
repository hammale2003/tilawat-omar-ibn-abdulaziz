// Plain data models. No framework types in here on purpose: this layer is
// pure Dart so it stays trivially testable.

class Surah {
  final int id;
  final String ar;
  final String en;
  final int ayahs;
  final String place; // مكية / مدنية

  const Surah({
    required this.id,
    required this.ar,
    required this.en,
    required this.ayahs,
    required this.place,
  });

  factory Surah.fromJson(Map<String, dynamic> j) => Surah(
        id: j['id'] as int,
        ar: j['ar'] as String,
        en: j['en'] as String,
        ayahs: j['ayahs'] as int,
        place: j['place'] as String,
      );

  /// Eastern-Arabic numerals, e.g. 114 -> ١١٤
  static String arabicDigits(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }
}

/// One audio file. The app's unit of playback.
///
/// This reciter has not published a complete mushaf, so a recording is not
/// always a whole surah: it may be an excerpt from a tarawih or tahajjud
/// prayer, or a standalone recitation such as the ruqya. [surahId] says which
/// surah it is drawn from, when that is known.
class Recording {
  final String id;
  final String section; // surahs | clips | special
  final String title;
  final int? surahId;
  final String url;
  final int bytes;
  final int secs;

  const Recording({
    required this.id,
    required this.section,
    required this.title,
    required this.surahId,
    required this.url,
    required this.bytes,
    required this.secs,
  });

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
        id: j['id'] as String,
        section: j['section'] as String,
        title: j['title'] as String,
        surahId: j['surah'] as int?,
        url: j['url'] as String,
        bytes: j['bytes'] as int,
        secs: j['secs'] as int,
      );

  Duration get duration => Duration(seconds: secs);
  bool get isWholeSurah => section == 'surahs';
  double get megabytes => bytes / 1e6;
}

class Section {
  final String id;
  final String ar;
  final String note;

  const Section({required this.id, required this.ar, required this.note});

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: j['id'] as String,
        ar: j['ar'] as String,
        note: (j['note'] as String?) ?? '',
      );
}

class ReciterInfo {
  final String ar;
  final String en;
  final String riwaya;
  final String source;

  const ReciterInfo({
    required this.ar,
    required this.en,
    required this.riwaya,
    required this.source,
  });

  factory ReciterInfo.fromJson(Map<String, dynamic> j) => ReciterInfo(
        ar: j['ar'] as String,
        en: j['en'] as String,
        riwaya: j['riwaya'] as String,
        source: j['source'] as String,
      );
}
