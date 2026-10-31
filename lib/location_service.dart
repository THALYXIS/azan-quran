import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cities.dart';

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
}

/// تحديد الموقع وحفظه (مشترك بين صفحة المواقيت وصفحة الإعدادات)
class LocationService {
  LocationService._();

  static Place? saved(SharedPreferences p) {
    final lat = p.getDouble('p_lat');
    final lng = p.getDouble('p_lng');
    if (lat == null || lng == null) return null;
    return Place(
      city: p.getString('p_city') ?? 'موقعك',
      lat: lat,
      lng: lng,
      cc: p.getString('p_cc'),
      fromGps: p.getBool('p_gps') ?? false,
    );
  }

  static Future<void> save(SharedPreferences p, Place pl) async {
    await p.setDouble('p_lat', pl.lat);
    await p.setDouble('p_lng', pl.lng);
    await p.setString('p_city', pl.city);
    await p.setBool('p_gps', pl.fromGps);
    if (pl.cc != null) {
      await p.setString('p_cc', pl.cc!);
    } else {
      await p.remove('p_cc');
    }
  }

  static String? _firstNonEmpty(List<String?> xs) {
    for (final x in xs) {
      if (x != null && x.trim().isNotEmpty) return x.trim();
    }
    return null;
  }

  static Place? nearestCity(double lat, double lng) {
    Place? best;
    var bestDistance = double.infinity;
    for (final c in kCities) {
      final d = Geolocator.distanceBetween(lat, lng, c.lat, c.lng);
      if (d < bestDistance) {
        bestDistance = d;
        best = c;
      }
    }
    return bestDistance <= 60000 ? best : null;
  }

  /// بتحدد موقعك بالـ GPS. بترمي LocationException برسالة مفهومة لو فشلت.
  static Future<Place> detect() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(
            'خدمة الموقع (GPS) مقفولة. شغّلها من إعدادات الموبايل وجرّب تاني، أو اختر مدينتك يدويًا.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        throw const LocationException(
            'لازم تسمح بصلاحية الموقع عشان نحدد مدينتك. تقدر كمان تختار المدينة يدويًا.');
      }
      if (perm == LocationPermission.deniedForever) {
        throw const LocationException(
            'صلاحية الموقع مرفوضة نهائيًا. فعّلها من إعدادات الموبايل ← التطبيقات ← أذان وقرآن ← الأذونات، أو اختر مدينتك يدويًا.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 25),
        ),
      );

      const fallbackName = 'موقعك الحالي';
      var city = fallbackName;
      String? cc;
      try {
        final marks = await Geocoding().placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
          locale: const Locale('ar'),
        );
        if (marks.isNotEmpty) {
          final m = marks.first;
          city = _firstNonEmpty(
                  [m.locality, m.subAdministrativeArea, m.administrativeArea]) ??
              fallbackName;
          cc = m.isoCountryCode;
        }
      } catch (_) {
        // لو مفيش نت للتعرف على اسم المدينة، نكمّل بأقرب مدينة معروفة
      }
      final near = nearestCity(pos.latitude, pos.longitude);
      if (near != null) {
        cc ??= near.cc;
        if (city == fallbackName) city = near.city;
      }

      return Place(
        city: city,
        lat: pos.latitude,
        lng: pos.longitude,
        cc: cc,
        fromGps: true,
      );
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException(
          'تعذر تحديد موقعك. اتأكد من الـ GPS أو اختر مدينتك يدويًا.');
    }
  }
}
