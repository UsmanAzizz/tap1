import 'package:flutter/material.dart';
import '../services/attendance_service.dart';

class AttendanceClock extends StatelessWidget {
  final DateTime now;
  final AttendanceService attendanceService;
  final Color Function(TimePhase) phaseColor;
  final IconData Function(TimePhase) phaseIcon;

  const AttendanceClock({
    super.key,
    required this.now,
    required this.attendanceService,
    required this.phaseColor,
    required this.phaseIcon,
  });

  bool get isUrgent => attendanceService.remainingTimeMasuk.inSeconds <= 180;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Jam utama
        Text(
          '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}.${now.second.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),

        // Status phase
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: phaseColor(attendanceService.currentPhase).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                phaseIcon(attendanceService.currentPhase),
                size: 18,
                color: phaseColor(attendanceService.currentPhase),
              ),
              const SizedBox(width: 6),
              Text(
                attendanceService.phaseText +
                    (attendanceService.phaseRemainingTime.inSeconds > 0
                        ? ' • ${attendanceService.formatDuration(attendanceService.phaseRemainingTime)}'
                        : ''),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: phaseColor(attendanceService.currentPhase),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Countdown sisa waktu absen (hanya muncul saat Belum Absen)
        if (attendanceService.status == 'Belum Absen' &&
            attendanceService.canAbsenMasuk)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isUrgent ? Colors.red : Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.alarm,
                  size: 18,
                  color: isUrgent ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sisa waktu absen: ${attendanceService.formatDuration(attendanceService.remainingTimeMasuk)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isUrgent ? Colors.red : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
