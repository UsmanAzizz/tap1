
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap1/main.dart';
import 'package:tap1/pages/notification.dart';
import 'package:tap1/services/calendar_widget.dart';
import 'package:tap1/widget/appbar.dart';
import 'package:tap1/widget/bubble_widget.dart';
import 'package:tap1/widget/drawer.dart';
import 'package:tap1/widget/location_status_card.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/attendance_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final locationService = LocationService();
  final attendanceService = AttendanceService();
final Random random = Random();
  DateTime now = DateTime.now();
  Timer? timer;
  DateTime? _pulangTime; // waktu pulang shift
  Duration remainingTime = Duration.zero;
  DateTime? _masukTime; // jam masuk shift
  late final VoidCallback onLogoutTap; 
  
  double? latitude;
  double? longitude;
  double? accuracy;
  bool isFetching = false;
  String? anomalyText;

  String localName = '';
  String _currentShift = '';
Color _phaseColor(TimePhase phase) {
  switch (phase) {
    case TimePhase.TENGGANG_MASUK:
      return Colors.orange;

    case TimePhase.KERJA:
      return Colors.green;

    case TimePhase.TENGGANG_PULANG:
      return Colors.blue; // 🔵 DIUBAH JADI BIRU

    case TimePhase.FREE:
    default:
      return Colors.blueGrey;
  }
}


IconData _phaseIcon(TimePhase phase) {
  switch (phase) {
    case TimePhase.TENGGANG_MASUK:
      return Icons.login;

    case TimePhase.KERJA:
      return Icons.work_history;

    case TimePhase.TENGGANG_PULANG:
      return Icons.home; // tetap oke untuk biru

    default:
      return Icons.free_breakfast;
  }
}

Future<void> _initAttendance() async {
  await attendanceService.loadShiftTimesFromLocal();   // load jam shift
  await attendanceService.loadLiburFromFirestore();    // load data libur
  setState(() {}); // update UI agar tombol absen ter-disable jika hari libur
}
  // Animation
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
Timer? _countdownTimer;
@override
@override
void initState() {
  super.initState();
SharedPreferences.getInstance().then((prefs) {
  final userName = prefs.getString('nama') ?? 'User';
  attendanceService.loadPermitFromFirestore(userName).then((_) {
    setState(() {});
  });
});

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _initAttendance();
    attendanceService.checkResetDaily();
    _loadLocalName();
    _getLocation();
  });
    attendanceService.loadLiburFromFirestore();   
 attendanceService.checkResetDaily();
  // Timer utama untuk jam sekarang + update countdown
  timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!mounted) return;

    setState(() {
      now = DateTime.now();

      // Update countdown MASUK
      if (attendanceService.status == 'Belum Absen' &&
          attendanceService.canAbsenMasuk) {
        attendanceService.remainingTimeMasuk =
            attendanceService.masukAkhir!.difference(now);
        if (attendanceService.remainingTimeMasuk.isNegative) {
          attendanceService.remainingTimeMasuk = Duration.zero;
        }
      }
 attendanceService.loadShiftTimesFromLocal().then((_) {
      setState(() {});
    });

    // Timer untuk print log setiap detik
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      
    });
 if (attendanceService.status == 'Sudah Masuk') {
  final now = DateTime.now();

  // Pastikan jam pulang sudah di-set
  if (attendanceService.pulangMulai != null && attendanceService.pulangAkhir != null) {
    if (now.isBefore(attendanceService.pulangMulai!)) {
      // belum waktunya pulang → hitung sisa sampai mulai pulang
      attendanceService.remainingTime = attendanceService.pulangMulai!.difference(now);
    } else if (now.isAfter(attendanceService.pulangAkhir!)) {
      // sudah lewat jam pulang akhir → set zero
      attendanceService.remainingTime = Duration.zero;
    } else {
      // sedang dalam interval pulang → hitung sisa sampai akhir pulang
      attendanceService.remainingTime = attendanceService.pulangAkhir!.difference(now);
    }
  } else {
    // fallback
    attendanceService.remainingTime = Duration.zero;
  }
}

    });
  });

  _getLocation();
  _loadLocalName();

  // Animasi fade
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  _controller.forward();

  // Load shift dari local storage
  SharedPreferences.getInstance().then((prefs) {
    final shift = prefs.getString('shift') ?? '';
    if (shift.isNotEmpty) {
      attendanceService.loadShiftTimesFromLocal();
    }
  });
}


  @override
  void dispose() {
    timer?.cancel();
      _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ------------------------- Method Asli -------------------------
  Future<void> _loadLocalName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('nama') ?? 'User';
    if (!mounted) return;
    setState(() {
      localName = name;
    });
  }
    bool get isUrgent => attendanceService.remainingTimeMasuk.inSeconds <= 180;
bool get isLocationValid {
  if (anomalyText == null) return false;
  // Nonaktifkan jika mengandung "⚠" (Fake GPS atau akurasi rendah atau di luar toko)
  return !anomalyText!.contains('⚠');
}
bool isButtonDisabled() {
  if (attendanceService.status == 'Sudah Pulang') return true;

  if (attendanceService.status == 'Belum Absen') {
    return attendanceService.remainingTimeMasuk.inSeconds > 0;
  }

  if (attendanceService.status == 'Sudah Masuk') {
    return attendanceService.remainingTime.inSeconds > 0;
  }

  return false;
}

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 12),
              const Text(
                'Anda akan diarahkan ke halaman login',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Keluar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('nama');

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyApp()),
      );
    }
  }

Future<void> _getLocation() async {
  if (isFetching) return; // cegah pemanggilan bersamaan

  setState(() {
    isFetching = true;
    anomalyText = null;
  });

  try {
    final pos = await locationService.getCurrentLocation();

    // Tambahkan delay minimal supaya animasi tombol terlihat
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    String anomalyResult;
    if (pos != null) {
      latitude = pos.latitude;
      longitude = pos.longitude;
      accuracy = pos.accuracy;
      anomalyResult = await locationService.detectAnomaly(pos); // async di luar setState
    } else {
      anomalyResult = 'Gagal mengambil lokasi';
    }

    // Update state secara synchronous
    if (!mounted) return;
    setState(() {
      anomalyText = anomalyResult;
    });
  } finally {
    if (!mounted) return;
    setState(() {
      isFetching = false;
    });
  }
}


// void handleAbsen() {
//   if (!mounted) return;
//   setState(() => attendanceService.handleAbsen());
// }

// void handleAbsenButton() async {
//   // panggil Firestore dulu
//   await attendanceService.handleAbsen();

//   // update UI secara synchronous
//   if (!mounted) return;
//   setState(() {});
// }

  Future<void> _openGoogleMaps() async {
    if (latitude == null || longitude == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
      );
    }
  }
  // ------------------------- END Method -------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
    drawer: AppDrawer(
  userName: localName,
  onLogoutTap: _confirmLogout, // harus sama persis dengan nama parameter di drawer
),

      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
                  const BubbleWidget(),
            CustomScrollView(
              slivers: [
SliverAppBar(
  pinned: true,
  expandedHeight: 90,
  backgroundColor: Colors.transparent,
  elevation: 0,
  forceElevated: true,
  automaticallyImplyLeading: false,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
  ),
flexibleSpace: Builder(
  builder: (context) {
    return HeaderWithSymbols(
      name: localName,
      onDrawerTap: () => Scaffold.of(context).openDrawer(),
    );
  },
),

),
  SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child:Column(
  children: [
    // Jam utama
    Text(
      '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}.${now.second.toString().padLeft(2, '0')}',
      style: const TextStyle(
          fontSize: 48, fontWeight: FontWeight.bold),
    ),
  const SizedBox(height: 6),

Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: _phaseColor(attendanceService.currentPhase).withOpacity(0.12),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        _phaseIcon(attendanceService.currentPhase),
        size: 18,
        color: _phaseColor(attendanceService.currentPhase),
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
          color: _phaseColor(attendanceService.currentPhase),
        ),
      ),
    ],
  ),
),


    // Countdown toleransi MASUK
    if (attendanceService.status == 'Belum Absen' &&
        attendanceService.canAbsenMasuk)


// Container(
//   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//   decoration: BoxDecoration(
//     color: (isUrgent ? Colors.red : Colors.blue).withOpacity(0.1),
//     borderRadius: BorderRadius.circular(20),
//     boxShadow: [
//       BoxShadow(
//         color: Colors.black.withOpacity(0.05),
//         blurRadius: 4,
//         offset: const Offset(0, 2),
//       ),
//     ],
//   ),
//   child: Row(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//       Icon(
//         Icons.alarm,
//         size: 18,
//         color: isUrgent ? Colors.red : Colors.blue,
//       ),
//       const SizedBox(width: 6),
//       Text(
//         'Sisa waktu absen: ${attendanceService.formatDuration(attendanceService.remainingTimeMasuk)}',
//         style: TextStyle(
//           fontSize: 14,
//           fontWeight: FontWeight.w600,
//           color: isUrgent ? Colors.red : Colors.blue,
//         ),
//       ),
//     ],
//   ),
// ),




    const SizedBox(height: 8),
    const AttendanceCalendar(),
    const SizedBox(height: 120),
  ],
),

                  ),
                ),
              ],
            ),
          LocationStatusCard(
  latitude: latitude,
  longitude: longitude,
  accuracy: accuracy,
  anomalyText: anomalyText,
  isFetching: isFetching,
  isLocationValid: isLocationValid,
  attendanceService: attendanceService,
  getLocation: _getLocation,
  openGoogleMaps: _openGoogleMaps,
  parentContext: context,
)

          ],
        ),
      ),
    );
  }
}


