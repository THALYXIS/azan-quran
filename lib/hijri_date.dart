import 'common.dart';

/// التاريخ الهجري بالحساب الجدولي (من غير مكتبات).
/// ممكن يختلف يوم عن الرؤية الرسمية، فيه إعداد للتعديل ±١ يوم في الإعدادات.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month; // 1..12
  final int day;

  static const List<String> monthNames = [
    'محرّم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  factory HijriDate.fromGregorian(DateTime date, {int adjust = 0}) {
    // نشتغل بـ UTC عشان نتجنب مشاكل تغيير التوقيت الصيفي
    final d = DateTime.utc(date.year, date.month, date.day + adjust);

    final a = (14 - d.month) ~/ 12;
    final y = d.year + 4800 - a;
    final m = d.month + 12 * a - 3;
    final jd = d.day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;

    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }

  String get monthName => monthNames[(month - 1).clamp(0, 11)];

  /// مثال: ١٨ جمادى الأولى ١٤٤٨ هـ
  String format() => '${arDigits(day)} $monthName ${arDigits(year)} هـ';
}
