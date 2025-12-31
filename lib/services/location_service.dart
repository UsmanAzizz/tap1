import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  final double radiusM = 100; // radius 100 meter

  Map<String, List<double>> tokoLocations = {}; // nama toko -> [lat, lon]

  /// Ambil lokasi toko dari SharedPreferences
  Future<void> loadTokoLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final locStr = prefs.getString('profile_location');
    if (locStr != null) {
      // format yang disimpan: {Toko1: lat,lon, Toko2: lat,lon}
      tokoLocations.clear();
      locStr.replaceAll(RegExp(r'[{}]'), '').split(', ').forEach((entry) {
        final splitIndex = entry.indexOf(':');
        if (splitIndex > 0) {
          final name = entry.substring(0, splitIndex);
          final latLon = entry.substring(splitIndex + 1).split(',');
          if (latLon.length == 2) {
            final lat = double.tryParse(latLon[0]);
            final lon = double.tryParse(latLon[1]);
            if (lat != null && lon != null) {
              tokoLocations[name] = [lat, lon];
            }
          }
        }
      });
    }
  }

  /// Mendapatkan posisi saat ini
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Deteksi anomaly lokasi
  Future<String> detectAnomaly(Position position) async {
    // Load lokasi toko dulu
    if (tokoLocations.isEmpty) {
      await loadTokoLocations();
    }

    // Fake GPS prioritas pertama
    if (position.isMocked) {
      return "⚠ Terindikasi Fake GPS!";
    }

    // Akurasi rendah prioritas kedua
    if (position.accuracy > 50) {
      return "⚠ Akurasi rendah: ±${position.accuracy.toStringAsFixed(1)} m";
    }

    // Cek setiap toko, jika salah satu dalam radius
    for (var entry in tokoLocations.entries) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        entry.value[0],
        entry.value[1],
      );
      if (distance <= radiusM) {
        return "Anda berada di area ${entry.key}";
      }
    }

    return "⚠ Anda di luar area toko";
  }
}
