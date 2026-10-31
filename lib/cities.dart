class Place {
  const Place({
    required this.city,
    required this.lat,
    required this.lng,
    this.cc,
    this.fromGps = false,
  });

  final String city;
  final double lat;
  final double lng;
  final String? cc; // رمز الدولة، مثل EG
  final bool fromGps;
}

/// مدن للاختيار اليدوي (لو الـ GPS مقفول أو الصلاحية مرفوضة)
const List<Place> kCities = [
  // مصر
  Place(city: 'القاهرة', lat: 30.0444, lng: 31.2357, cc: 'EG'),
  Place(city: 'الإسكندرية', lat: 31.2001, lng: 29.9187, cc: 'EG'),
  Place(city: 'الجيزة', lat: 30.0131, lng: 31.2089, cc: 'EG'),
  Place(city: 'بورسعيد', lat: 31.2653, lng: 32.3019, cc: 'EG'),
  Place(city: 'السويس', lat: 29.9668, lng: 32.5498, cc: 'EG'),
  Place(city: 'الإسماعيلية', lat: 30.5965, lng: 32.2715, cc: 'EG'),
  Place(city: 'دمياط', lat: 31.4165, lng: 31.8133, cc: 'EG'),
  Place(city: 'طنطا', lat: 30.7865, lng: 31.0004, cc: 'EG'),
  Place(city: 'المنصورة', lat: 31.0409, lng: 31.3785, cc: 'EG'),
  Place(city: 'الزقازيق', lat: 30.5877, lng: 31.5020, cc: 'EG'),
  Place(city: 'المنيا', lat: 28.1099, lng: 30.7503, cc: 'EG'),
  Place(city: 'أسيوط', lat: 27.1783, lng: 31.1859, cc: 'EG'),
  Place(city: 'الأقصر', lat: 25.6872, lng: 32.6396, cc: 'EG'),
  Place(city: 'أسوان', lat: 24.0889, lng: 32.8998, cc: 'EG'),
  Place(city: 'الغردقة', lat: 27.2579, lng: 33.8116, cc: 'EG'),
  Place(city: 'شرم الشيخ', lat: 27.9158, lng: 34.3300, cc: 'EG'),
  Place(city: 'مرسى مطروح', lat: 31.3543, lng: 27.2373, cc: 'EG'),
  // الخليج والشام والعراق واليمن
  Place(city: 'مكة المكرمة', lat: 21.3891, lng: 39.8579, cc: 'SA'),
  Place(city: 'المدينة المنورة', lat: 24.5247, lng: 39.5692, cc: 'SA'),
  Place(city: 'الرياض', lat: 24.7136, lng: 46.6753, cc: 'SA'),
  Place(city: 'جدة', lat: 21.4858, lng: 39.1925, cc: 'SA'),
  Place(city: 'دبي', lat: 25.2048, lng: 55.2708, cc: 'AE'),
  Place(city: 'أبوظبي', lat: 24.4539, lng: 54.3773, cc: 'AE'),
  Place(city: 'الكويت', lat: 29.3759, lng: 47.9774, cc: 'KW'),
  Place(city: 'الدوحة', lat: 25.2854, lng: 51.5310, cc: 'QA'),
  Place(city: 'المنامة', lat: 26.2285, lng: 50.5860, cc: 'BH'),
  Place(city: 'مسقط', lat: 23.5880, lng: 58.3829, cc: 'OM'),
  Place(city: 'عمّان', lat: 31.9454, lng: 35.9284, cc: 'JO'),
  Place(city: 'القدس', lat: 31.7683, lng: 35.2137, cc: 'PS'),
  Place(city: 'بيروت', lat: 33.8938, lng: 35.5018, cc: 'LB'),
  Place(city: 'دمشق', lat: 33.5138, lng: 36.2765, cc: 'SY'),
  Place(city: 'بغداد', lat: 33.3152, lng: 44.3661, cc: 'IQ'),
  Place(city: 'صنعاء', lat: 15.3694, lng: 44.1910, cc: 'YE'),
  // السودان والمغرب العربي
  Place(city: 'الخرطوم', lat: 15.5007, lng: 32.5599, cc: 'SD'),
  Place(city: 'طرابلس', lat: 32.8872, lng: 13.1913, cc: 'LY'),
  Place(city: 'تونس', lat: 36.8065, lng: 10.1815, cc: 'TN'),
  Place(city: 'الجزائر', lat: 36.7538, lng: 3.0588, cc: 'DZ'),
  Place(city: 'الرباط', lat: 34.0209, lng: -6.8416, cc: 'MA'),
  Place(city: 'الدار البيضاء', lat: 33.5731, lng: -7.5898, cc: 'MA'),
  // أخرى
  Place(city: 'إسطنبول', lat: 41.0082, lng: 28.9784, cc: 'TR'),
];
