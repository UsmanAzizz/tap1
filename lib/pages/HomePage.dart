import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap1/main.dart';
import 'package:tap1/pages/notification.dart';
import 'package:tap1/services/calendar_widget.dart';
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
      return Icons.work;

    case TimePhase.TENGGANG_PULANG:
      return Icons.home; // tetap oke untuk biru

    default:
      return Icons.free_breakfast;
  }
}


  // Animation
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
Timer? _countdownTimer;
@override
void initState() {
  super.initState();
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child:
                  Text('Molecule.io', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
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
  automaticallyImplyLeading: false, // 🔴 Hapus burger otomatis
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
  ),
  flexibleSpace: Stack(
    children: [
      // Background gradient + shadow
      Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color.fromARGB(255, 49, 158, 248), Color.fromARGB(255, 59, 131, 220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 0,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),

      // Floating shapes
      Positioned(
        top: 50,
        right: 40,
        child: CircleAvatar(radius: 12, backgroundColor: Colors.white.withOpacity(0.1)),
      ),
      // Positioned(
      //   top: 40,
      //   left: 5,
      //   child: CircleAvatar(radius: 18, backgroundColor: Colors.yellow.withOpacity(1)),
      // ),
      Positioned(
        top: 70,
        right: 50,
        child: CircleAvatar(radius: 6, backgroundColor: Colors.yellow.withOpacity(0.1)),
      ),

      // Teks di kiri bawah
    // Teks di kiri bawah




Positioned(
  left: 20,
  bottom: 30,
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      // Simbol mengambang acak
      ...List.generate(15, (index) {
        final symbols = ['X', 'O', '▢', '△'];
        final symbol = symbols[random.nextInt(symbols.length)];
        final leftOffset = random.nextDouble() * 50; // posisi acak horizontal
        final topOffset = random.nextDouble() *120;  // posisi acak vertikal
        final opacity = 0.05 + random.nextDouble() * 0.15; // opacity acak
        final fontSize = 10 + random.nextInt(6); // ukuran acak 10-15

        return Positioned(
          left: leftOffset,
          top: topOffset,
          child: Text(
            symbol,
            style: TextStyle(
              color: Colors.white.withOpacity(opacity),
              fontSize: fontSize.toDouble(),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }),

      // Teks utama
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 0),
          const Text(
            'Gaya Group',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ],
  ),
),



      // Matahari kanan bawah (fungsi drawer)
      Positioned(
        bottom: 40,
        right: 16,
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Icon(
              Icons.wb_sunny,
              color: Colors.yellowAccent,
              size: 28,
            ),
          ),
        ),
      ),
    ],
  ),
)
,
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




    const SizedBox(height: 8),
    const AttendanceCalendar(),
    const SizedBox(height: 120),
  ],
),

                  ),
                ),
              ],
            ),
            Align(
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
        onPressed: (latitude != null && longitude != null) ? _openGoogleMaps : null,
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
        onPressed: isFetching ? null : _getLocation,
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
)
,
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: attendanceService.isButtonDisabled
                    ? null
                    : () async {
                        if (!mounted) return;

                        if (!isLocationValid) {
                          showTopNotification(
                            context,
                            success: false,
                            message: 'Lokasi tidak valid!',
                          );
                          return;
                        }

                        final prefs = await SharedPreferences.getInstance();
                        final userName = prefs.getString('nama') ?? 'User';

                        final resultMessage =
                            await attendanceService.handleAbsenWithNotif(userName);

                        if (!mounted) return;
                        setState(() {});

                        showTopNotification(
                          context,
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
    // Icon matahari di pojok kanan atas
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
)

              ),
            ),
          ],
        ),
      ),
    );
  }
}


class Bubble {
  double x;
  double y;
  double size;
  double speed;
  double dx;
  double opacity;
  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.dx,
    required this.opacity,
  });
}

class BubbleWidget extends StatefulWidget {
  const BubbleWidget({super.key});

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  final int bubbleCount = 20;
  final List<Bubble> bubbles = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < bubbleCount; i++) {
      bubbles.add(_createBubble());
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1000),
    )..addListener(_updateBubbles);

    _controller.repeat();
  }

  Bubble _createBubble() {
    double size = 15 + _random.nextDouble() * 25; // ukuran 15..40
    return Bubble(
      x: _random.nextDouble(),
      y: 1.0 + _random.nextDouble(), // start di bawah layar
      size: size,
      speed: 0.0008 + _random.nextDouble() * 0.0015, // lebih lambat
      dx: (_random.nextDouble() - 0.5) * 0.003, // pergerakan horizontal kecil
      opacity: 0.3 + _random.nextDouble() * 0.5, // fading halus
    );
  }

  void _updateBubbles() {
    setState(() {
      for (var b in bubbles) {
        b.y -= b.speed;
        b.x += b.dx;

        // Reset jika keluar layar
        if (b.y < -0.1 || b.x < -0.1 || b.x > 1.1) {
          var newB = _createBubble();
          b.y = newB.y;
          b.x = newB.x;
          b.size = newB.size;
          b.speed = newB.speed;
          b.dx = newB.dx;
          b.opacity = newB.opacity;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: bubbles.map((b) {
          return Positioned(
            left: b.x * constraints.maxWidth,
            top: b.y * constraints.maxHeight,
            child: Opacity(
              opacity: b.opacity,
              child: Container(
                width: b.size,
                height: b.size,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

