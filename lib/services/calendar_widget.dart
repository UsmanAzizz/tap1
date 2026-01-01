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
  int hitungLiburBulanIni() {
    int total = 0;
    liburEvents.forEach((date, value) {
      if (date.year == focusedDay.year &&
          date.month == focusedDay.month &&
          (value == '0' || value == '1')) {
        total++;
      }
    });
    return total;
  }

  /// Ajukan libur
  Future<void> ajukanLibur(DateTime day) async {
    if (localName == null || localName!.isEmpty) return;

    if (hitungLiburBulanIni() >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maksimal 2 kali libur dalam 1 bulan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      // Cek apakah value untuk pulang != null
      if (value != null) {
        hasPulang = true;
      }
    }
  });

  Color? bgColor;
  Color textColor = Colors.black;
  bool showInnerWhite = false;

  if (day.isBefore(today)) {
    if (isTelat) {
      bgColor = Colors.red;
      textColor = Colors.white;
      if (hasPulang) {
        showInnerWhite = true;
        textColor = Colors.red;
      }
    } else if (isLiburApproved) {
      bgColor = Colors.deepPurpleAccent;
      textColor = Colors.white;
    } else if (isLiburPending) {
      bgColor = Colors.yellow.shade700;
      textColor = Colors.white;
    } else if (hasMasuk && hasPulang) {
      // hadir lengkap → hijau
      bgColor = Colors.green;
      textColor = Colors.white;
    } else if (hasMasuk && !hasPulang) {
      // hanya absen masuk → biru
      bgColor = Colors.blue;
      textColor = Colors.white;
    } else {
      // tanggal lewat tapi tidak hadir sama sekali → merah
      bgColor = Colors.red;
      textColor = Colors.white;
    }
  } else {
    // hari ini / mendatang
    if (isTelat) {
      bgColor = Colors.red;
      textColor = Colors.white;
      if (hasPulang) {
        showInnerWhite = true;
        textColor = Colors.red;
      }
    } else if (isLiburApproved) {
      bgColor = Colors.deepPurpleAccent;
      textColor = Colors.white;
    } else if (isLiburPending) {
      bgColor = Colors.yellow.shade700;
      textColor = Colors.white;
    } else if (hasMasuk && !hasPulang) {
      bgColor = Colors.blue;
      textColor = Colors.white;
    } else if (hasMasuk && hasPulang) {
      bgColor = Colors.green;
      textColor = Colors.white;
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
    final liburForDay = _getLiburForDay(day);
    final statusText = liburForDay.isEmpty
        ? 'Belum ada data'
        : liburForDay.first == '1'
            ? 'Libur Disetujui'
            : 'Libur diajukan';

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
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${day.day}-${day.month}-${day.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('$statusText'),
                  const SizedBox(height: 12),
                  if (liburForDay.isEmpty && hitungLiburBulanIni() < 2)
                    ElevatedButton(
                      onPressed: () async {
                        await ajukanLibur(day);
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      child: const Text('Ajukan Libur'),
                    ),
                  if (liburForDay.contains('0'))
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await _batalkanPengajuan(day);
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Batalkan Pengajuan',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pendingText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 0),
                            child: Text(
                              '$pendingText $pendingTanggal',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        if (approvedText != null)
                          Text(
                            '$approvedText $approvedTanggal',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                        Text(
                          'Sisa kuota libur : ${2 - hitungLiburBulanIni()}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
