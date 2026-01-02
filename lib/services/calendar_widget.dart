import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap1/pages/notification.dart';

class AttendanceCalendar extends StatefulWidget {
  const AttendanceCalendar({super.key});

  @override
  State<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends State<AttendanceCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
Map<DateTime, Map<String, DateTime?>> attendanceMap = {};

  /// Absen biasa: 1 = hadir, 0 = belum hadir


  /// Hanya untuk libur / pengajuan libur: 0 = pending, 1 = approved
  Map<DateTime, String> liburEvents = {};
  Map<DateTime, String> telatEvents = {};

  String? localName;

  @override
  void initState() {
    super.initState();
    _loadLocalNameAndData();
  }

  // Helper untuk hanya tanggal tanpa jam
  DateTime onlyDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Load data telat
Future<void> loadTelatFromFirebase(String name, {DateTime? forMonth}) async {
  try {
    final monthRef = forMonth ?? focusedDay;
    final year = monthRef.year.toString();
    final month = monthRef.month.toString(); // 1, 2, dst sesuai Firestore

    final docSnapshot = await FirebaseFirestore.instance
        .collection('telat')
        .doc(year)
        .collection(month)
        .doc(name)
        .get();

    if (!docSnapshot.exists) return;

    final data = docSnapshot.data()!;
    Map<DateTime, String> temp = {};

    data.forEach((key, value) {
      // Ambil 2 karakter pertama dari key → tanggal
      if (key.length >= 2) {
        final dayPart = key.substring(0, 2); // "01" dari "01_telat"
        final day = int.tryParse(dayPart);
        if (day != null) {
          final dateKey = onlyDate(DateTime(monthRef.year, monthRef.month, day));
          temp[dateKey] = value.toString(); // '1' = telat
        }
      }
    });

    if (!mounted) return;
    setState(() {
      telatEvents = temp;
    });

    // Cek apakah ada data telat
    if (telatEvents.isNotEmpty) {
      debugPrint('✅ Ada data telat untuk bulan ini: ${telatEvents.keys.toList()}');
    } else {
      debugPrint('❌ Tidak ada data telat untuk bulan ini');
    }

  } catch (e) {
    debugPrint('Gagal load data telat: $e');
  }
}



  Future<void> _loadLocalNameAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('nama') ?? '';
    if (!mounted) return;

    setState(() {
      localName = name;
    });

    if (name.isNotEmpty) {
      await loadAttendanceFromFirebase(name);
      await loadLiburFromFirebase(name);
      await loadTelatFromFirebase(name);
    }
  }

  /// Load absen biasa
// Di bagian _AttendanceCalendarState
// Ubah tipe firebaseEvents
Map<DateTime, DateTime?> firebaseEvents = {};

Future<void> loadAttendanceFromFirebase(String name) async {
  try {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString();

    final userDoc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(year)
        .collection(month)
        .doc(name)
        .get();

    if (!userDoc.exists) return;

    final data = userDoc.data() ?? {};
    Map<DateTime, Map<String, DateTime?>> temp = {};

    data.forEach((key, value) {
      // key = '01_masuk', '02_pulang', dsb
      final parts = key.split('_'); // ["01", "masuk"]
      if (parts.length != 2) return;

      final dayInt = int.tryParse(parts[0]);
      final type = parts[1]; // "masuk" atau "pulang"

      if (dayInt != null) {
        final dateKey = DateTime(now.year, now.month, dayInt);

        // pastikan map untuk tanggal ada
        temp[dateKey] = temp[dateKey] ?? {'masuk': null, 'pulang': null};

        if (value is Timestamp) {
          temp[dateKey]![type] = value.toDate();
        } else if (value is DateTime) {
          temp[dateKey]![type] = value;
        } else {
          temp[dateKey]![type] = null;
        }
      }
    });

    if (!mounted) return;
    setState(() {
      attendanceMap = temp; // assign ke field
    });
  } catch (e) {
    debugPrint('Gagal load data absen: $e');
  }
}




  /// Load data libur / pengajuan libur
  Future<void> loadLiburFromFirebase(String name, {DateTime? forMonth}) async {
    try {
      final monthRef = forMonth ?? focusedDay;
      final year = monthRef.year.toString();
      final month = monthRef.month.toString();

      final userDoc = await FirebaseFirestore.instance
          .collection('permit')
          .doc(year)
          .collection(month)
          .doc(name)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      Map<DateTime, String> temp = {};
      data.forEach((key, value) {
        final day = int.tryParse(key);
        if (day != null) {
          temp[onlyDate(DateTime(monthRef.year, monthRef.month, day))] =
              value.toString();
        }
      });

      if (!mounted) return;
      setState(() {
        liburEvents = temp;
      });
    } catch (e) {
      debugPrint('Gagal load data libur: $e');
    }
  }

  /// Hitung jumlah libur pending + approved bulan ini


  /// Ajukan libur
  Future<void> ajukanLibur(DateTime day) async {
    if (localName == null || localName!.isEmpty) return;

  

    final year = day.year.toString();
    final month = day.month.toString();
    final tanggal = day.day.toString();

    try {
      await FirebaseFirestore.instance
          .collection('permit')
          .doc(year)
          .collection(month)
          .doc(localName)
          .set(
        {tanggal: '0'},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      await loadLiburFromFirebase(localName!, forMonth: day);

      if (!mounted) return;
      setState(() {
        liburEvents[onlyDate(day)] = '0';
      });

      showTopNotification(
        context,
        message: 'Libur berhasil diajukan!',
        success: true,
      );
    } catch (e) {
      debugPrint('Gagal mengajukan libur: $e');
      showTopNotification(
        context,
        message: 'Gagal mengajukan libur',
        success: false,
      );
    }
  }

  List<String> _getLiburForDay(DateTime day) {
    final key = onlyDate(day);
    if (!liburEvents.containsKey(key)) return [];
    return [liburEvents[key]!];
  }

Widget _buildDayCell(DateTime day) {
  final dayKey = onlyDate(day);
  final today = onlyDate(DateTime.now());

  // Ambil semua absen untuk hari ini
  final allAttendanceKeys = firebaseEvents.entries
      .where((e) => onlyDate(e.key) == dayKey)
      .map((e) => e.key)
      .toList();

  final telatForDay = telatEvents[dayKey];       // '1' jika telat
  final liburForDay = _getLiburForDay(day);      // '0' = pending, '1' = approved

  bool isTelat = telatForDay != null && telatForDay.toString() == '1';
  bool isLiburApproved = liburForDay.contains('1');
  bool isLiburPending = liburForDay.contains('0');

  // Cek hadir masuk & pulang dari attendanceMap
  final attendanceForDay = attendanceMap[dayKey];
  bool hasMasuk = attendanceForDay != null && attendanceForDay['masuk'] != null;
  bool hasPulang = attendanceForDay != null && attendanceForDay['pulang'] != null;

  // Cek tidak ada absen sama sekali (tanggal sebelum ini)
  bool belumAbsen = !isTelat && !hasMasuk && !hasPulang && day.isBefore(DateTime.now());

  firebaseEvents.forEach((key, value) {
    if (key.year == day.year && key.month == day.month && key.day == day.day) {
      if (value != null) hasPulang = true;
    }
  });

  Color? bgColor;
  Color textColor = Colors.black;
  bool showInnerWhite = false;

  if (day.isBefore(today)) {
    if (isLiburApproved) {
      bgColor = Colors.deepPurpleAccent;
      textColor = Colors.white;
    } else if (isLiburPending) {
      bgColor = Colors.yellow.shade700;
      textColor = Colors.white;
    } else {
      // ===========================
      // LOGIKA BARU ATTENDANCE
      // ===========================
      if (hasMasuk && !isTelat && !hasPulang) {
        // Masuk saja
        bgColor = Colors.blue;
        textColor = Colors.white;
      } else if (hasMasuk && isTelat && !hasPulang) {
        // Masuk telat saja
        bgColor = Colors.red;
        showInnerWhite = true;
        textColor = Colors.red;
      } else if (!hasMasuk && !isTelat && hasPulang) {
        // Pulang saja
        bgColor = Colors.blue;
        showInnerWhite = true;
        textColor = Colors.blue;
      } else if (hasMasuk && !isTelat && hasPulang) {
        // Masuk & pulang
        bgColor = Colors.green;
        textColor = Colors.white;
      } else if (hasMasuk && isTelat && hasPulang) {
        // Masuk telat & pulang
        bgColor = Colors.green;
        showInnerWhite = true;
        textColor = Colors.green;
      } else {
        // Tidak hadir sama sekali → tetap merah
        bgColor = Colors.red;
        textColor = Colors.white;
      }
    }
  } else {
    // Hari ini / mendatang tetap mengikuti status
    if (isLiburApproved) {
      bgColor = Colors.deepPurpleAccent;
      textColor = Colors.white;
    } else if (isLiburPending) {
      bgColor = Colors.yellow.shade700;
      textColor = Colors.white;
    } else if (hasMasuk && !isTelat && !hasPulang) {
      bgColor = Colors.blue;
      textColor = Colors.white;
    } else if (!hasMasuk && !isTelat && hasPulang) {
      bgColor = Colors.blue;
      showInnerWhite = true;
      textColor = Colors.blue;
    }else if (!hasMasuk && isTelat && !hasPulang) {
      bgColor = Colors.red;
      showInnerWhite = true;
      textColor = Colors.red;
    }  else if (hasMasuk && !isTelat && hasPulang) {
      bgColor = Colors.green;
      textColor = Colors.white;
    } else if (hasMasuk && isTelat && hasPulang) {
      bgColor = Colors.green;
      showInnerWhite = true;
      textColor = Colors.green;
    } else {
      bgColor = null;
      textColor = Colors.black;
    }
  }

  return Container(
    margin: const EdgeInsets.all(4),
    alignment: Alignment.center,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (bgColor != null)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
          ),
        if (showInnerWhite)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}


void _showAttendanceDialog(DateTime day) {
  final attendanceForDay = attendanceMap[onlyDate(day)];
  final masuk = attendanceForDay?['masuk'];
  final pulang = attendanceForDay?['pulang'];
  final telatForDay = telatEvents[onlyDate(day)] == '1';
  final liburForDay = _getLiburForDay(day);
  final isLiburApproved = liburForDay.contains('1');
  final isLiburPending = liburForDay.contains('0');

  final canApplyLibur =
      !isLiburApproved && !isLiburPending && masuk == null && pulang == null && !telatForDay;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "AttendanceDialog",
    barrierColor: Colors.black.withOpacity(0.3),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.65,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bulan & Tahun
                Text(
                  '${day.month} ${day.year}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 6),

                // Tanggal besar
                Text(
                  '${day.day}',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 0),

                // Status bar: masuk, pulang, telat, libur
              if (masuk != null)
  _infoBar(
    icon: Icons.login,
    label: 'Anda masuk jam ${TimeOfDay.fromDateTime(masuk).format(context)}',
    color: Colors.blue,
  ),
if (telatForDay)
  _infoBar(
    icon: Icons.access_time,
    label: 'Anda telat${masuk != null ? ": ${TimeOfDay.fromDateTime(masuk).format(context)}" : ""}',
    color: Colors.orange,
  ),
if (pulang != null)
  _infoBar(
    icon: Icons.logout,
    label: 'Anda pulang jam ${TimeOfDay.fromDateTime(pulang).format(context)}',
    color: Colors.green,
  ),

                if (isLiburApproved)
                  _infoBar(
                    icon: Icons.coffee,
                    label: 'Libur Disetujui',
                   
                    color: Colors.purple,
                  ),
                const SizedBox(height: 16),

                // Tombol Ajukan / Batalkan Libur
                if (canApplyLibur)
               ElevatedButton(
  onPressed: () {
    // Tutup dialog dulu
    Navigator.of(context, rootNavigator: true).pop();

    // Jalankan ajukan libur async setelah dialog ditutup
    Future.microtask(() => ajukanLibur(day));
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue.shade600,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32),
    ),
    elevation: 2,
  ),
  child: const Text(
    'Ajukan Libur',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    ),
  ),
)

                else if (isLiburPending)
                  ElevatedButton(
                    onPressed: () async {
                        // Tutup dialog setelah berhasil
    Navigator.of(context, rootNavigator: true).pop();
    await _batalkanPengajuan(day);
  
  },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text(
                      'Batalkan Pengajuan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                const SizedBox(height: 12),
                // Tombol tutup
              TextButton(
  onPressed: () => Navigator.pop(context),
  style: TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    backgroundColor: Colors.red.shade600.withOpacity(0.1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32),
    ),
  ),
  child: const Text(
    'Tutup',
    style: TextStyle(
      color: Colors.red,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
  ),
)

              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}


Widget _infoBar({
  required IconData icon,
  required String label,
  Color? color,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color?.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center, // <-- tengah
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    ),
  );
}




  Future<void> _batalkanPengajuan(DateTime day) async {
    if (localName == null || localName!.isEmpty) return;

    final year = day.year.toString();
    final month = day.month.toString();
    final tanggal = day.day.toString();

    try {
      await FirebaseFirestore.instance
          .collection('permit')
          .doc(year)
          .collection(month)
          .doc(localName)
          .update({tanggal: FieldValue.delete()});

      if (!mounted) return;
      setState(() {
        liburEvents.remove(onlyDate(day));
      });

      showTopNotification(
        context,
        message: 'Pengajuan libur tanggal $tanggal dibatalkan',
        success: true,
      );
    } catch (e) {
      debugPrint('Gagal membatalkan pengajuan: $e');
      showTopNotification(
        context,
        message: 'Gagal membatalkan pengajuan',
        success: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<int> pending = [];
    List<int> approved = [];
    liburEvents.forEach((date, status) {
      if (date.year == focusedDay.year && date.month == focusedDay.month) {
        if (status == '0') pending.add(date.day);
        if (status == '1') approved.add(date.day);
      }
    });

    String? pendingText =
        pending.isNotEmpty ? 'Libur telah diajukan untuk tanggal' : null;
    String? approvedText =
        approved.isNotEmpty ? 'Libur diterima untuk tanggal' : null;

    String pendingTanggal = pending.join(', ');
    String approvedTanggal = approved.join(', ');

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: focusedDay,
          calendarFormat: _calendarFormat,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          onPageChanged: (focused) async {
            setState(() => focusedDay = focused);
            if (localName != null && localName!.isNotEmpty) {
              await loadLiburFromFirebase(localName!, forMonth: focused);
              await loadTelatFromFirebase(localName!, forMonth: focused);
            }
          },
          onDaySelected: (selected, focused) {
            setState(() {
              selectedDay = selected;
              focusedDay = focused;
            });
            _showAttendanceDialog(selected);
          },
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) => _buildDayCell(day),
            todayBuilder: (context, day, focusedDay) => _buildDayCell(day),
          ),
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(),
          ),
        ),
        const SizedBox(height: 0),
        if (pendingText != null || approvedText != null)
          AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 500),
            child: Container(
  width: double.infinity, // pastikan Row lebar penuh
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
    Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Info libur pending
      if (pendingText != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$pendingText $pendingTanggal',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

      // Info libur approved
      if (approvedText != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$approvedText $approvedTanggal',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

      // Sisa kuota libur
   

      const SizedBox(height: 8),

      // Tombol Ajukan / Batalkan Libur
   
    ],
  ),
)

    ],
  ),
)

          ),
      ],
    );
  }
}
