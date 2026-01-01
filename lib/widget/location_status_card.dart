import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/attendance_service.dart';
import '../pages/notification.dart';

class LocationStatusCard extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? anomalyText;
  final bool isFetching;
  final bool isLocationValid;
  final AttendanceService attendanceService;
  final Future<void> Function() getLocation;
  final Future<void> Function() openGoogleMaps;
  final BuildContext parentContext;

  const LocationStatusCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.anomalyText,
    required this.isFetching,
    required this.isLocationValid,
    required this.attendanceService,
    required this.getLocation,
    required this.openGoogleMaps,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 0,
              offset: Offset(0, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  ' Status Lokasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      accuracy != null
                          ? ' Akurasi ± ${accuracy!.toStringAsFixed(1)} m'
                          : 'Mengambil lokasi...',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    if (anomalyText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: anomalyText!.contains("⚠") ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          anomalyText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Row(
                      children: [
                        // Tombol buka Google Maps
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed:
                                (latitude != null && longitude != null) ? () => openGoogleMaps() : null,
                            icon: const Icon(Icons.location_on, color: Colors.redAccent, size: 24),
                            tooltip: 'Buka Google Maps',
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Tombol refresh lokasi
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: isFetching ? null : () => getLocation(),
                            icon: isFetching
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.blue,
                                    ),
                                  )
                                : const Icon(Icons.refresh, color: Colors.blue, size: 24),
                            tooltip: 'Refresh Lokasi',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: attendanceService.isButtonDisabled
                            ? null
                            : () async {
                                if (!isLocationValid) {
                                  showTopNotification(
                                    parentContext,
                                    success: false,
                                    message: 'Lokasi tidak valid!',
                                  );
                                  return;
                                }

                                final prefs = await SharedPreferences.getInstance();
                                final userName = prefs.getString('nama') ?? 'User';

                                final resultMessage =
                                    await attendanceService.handleAbsenWithNotif(userName);

                                showTopNotification(
                                  parentContext,
                                  success: resultMessage.startsWith('✅'),
                                  message: resultMessage,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: attendanceService.isButtonDisabled
                              ? Colors.grey.shade300
                              : Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          attendanceService.buttonText.isEmpty
                              ? 'TIDAK DAPAT MELAKUKAN AKSI'
                              : attendanceService.buttonText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.wb_sunny,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
