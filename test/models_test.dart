import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/data/models.dart';

void main() {
  group('Surah.arabicDigits', () {
    test('converts western digits to eastern-arabic', () {
      expect(Surah.arabicDigits(1), '١');
      expect(Surah.arabicDigits(30), '٣٠');
      expect(Surah.arabicDigits(114), '١١٤');
      expect(Surah.arabicDigits(286), '٢٨٦');
    });
  });

  group('Recording', () {
    Recording make(Map<String, dynamic> over) => Recording.fromJson({
          'id': 't001_2',
          'section': 'surahs',
          'title': 'سورة البقرة',
          'surah': 2,
          'url': 'https://example.invalid/002.mp3',
          'bytes': 107394611,
          'secs': 6712,
          ...over,
        });

    test('parses a whole-surah recording', () {
      final r = make({});
      expect(r.surahId, 2);
      expect(r.isWholeSurah, isTrue);
      expect(r.duration, const Duration(seconds: 6712));
      expect(r.megabytes, closeTo(107.4, 0.1));
    });

    test('an excerpt is not a whole surah but still knows its surah', () {
      final r = make({'id': 't034_10', 'section': 'clips', 'surah': 10, 'title': 'خواتيم سورة يونس'});
      expect(r.isWholeSurah, isFalse);
      expect(r.surahId, 10);
    });

    test('a standalone recitation has no surah at all', () {
      final r = make({'id': 't069_0', 'section': 'special', 'surah': null, 'title': 'الرقية الشرعية'});
      expect(r.surahId, isNull);
      expect(r.isWholeSurah, isFalse);
    });
  });

  group('Section', () {
    test('parses, tolerating a missing note', () {
      final s = Section.fromJson({'id': 'clips', 'ar': 'تلاوات'});
      expect(s.id, 'clips');
      expect(s.ar, 'تلاوات');
      expect(s.note, '');
    });
  });

  group('Surah', () {
    test('parses from json', () {
      final s = Surah.fromJson(
          {'id': 112, 'ar': 'الإخلاص', 'en': 'Al-Ikhlas', 'ayahs': 4, 'place': 'مكية'});
      expect(s.id, 112);
      expect(s.ar, 'الإخلاص');
      expect(s.ayahs, 4);
    });
  });
}
