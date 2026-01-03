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
  Map<DateTime, String> swapEvents = {};

  String? localName;

  @override
void initState() {
  super.initState();
  _initData();
}

Future<void> _initData() async {
  await _loadLocalNameAndData(); // pastikan localName sudah ada

  if (localName == null) return;

  await fetchSwapEvents(
    user: localName!, // aman karena sudah dicek
    year: focusedDay.year,
    month: focusedDay.month,
  );

  setState(() {});
}


  // Helper untuk hanya tanggal tanpa jam
DateTime onlyDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

Future<void> _cancelSwapShift(
  BuildContext context,
  String user,
  DateTime day,
) async {
  try {
    final year = day.year.toString();
    final month = day.month.toString(); // 1 digit jika < 10
    final dateKey = day.day.toString(); // FIELD = tanggal

    final docRef = FirebaseFirestore.instance
        .collection('swap')
        .doc(year)
        .collection(month)
        .doc(user);

    await docRef.update({
      dateKey: FieldValue.delete(),
    });

    // hapus dari local map agar UI langsung update
    swapEvents.remove(DateTime(day.year, day.month, day.day));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tukar shift berhasil dibatalkan')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal membatalkan tukar shift: $e')),
    );
  }
}

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

Future<void> showSwapFieldDialog(
    BuildContext context, String user, DateTime day) async {
  final currentContext = context;

  try {
    // Ambil dokumen "List" dari collection swap
    final docSnapshot =
        await FirebaseFirestore.instance.collection('swap').doc('List').get();

    if (!docSnapshot.exists) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Dokumen "List" tidak ditemukan')),
      );
      return;
    }

    // Ambil nama-nama field dari dokumen (misal shift 1, 2, 3)
    final fieldNames = docSnapshot.data()!.keys.toList();

    // Tampilkan dialog
    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Pilih shift untuk swap'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: fieldNames.length,
            itemBuilder: (context, index) {
              final shiftSelected = fieldNames[index];
              return ListTile(
                leading: const Icon(Icons.label),
                title: Text(shiftSelected),
                onTap: () async {
                  try {
                    // Nama field = tanggal
                    final fieldKey = day.day.toString();

                    // Value = shift yang dipilih + "_0"
                    final fieldValue = "${shiftSelected}_0";

                    // Path Firestore: swap/(tahun)/(bulan 2 digit)/(user)
                    final docRef = FirebaseFirestore.instance
                        .collection('swap')
                        .doc(day.year.toString())
                        .collection(day.month.toString())
                        .doc(user);

                    // Set field
                    await docRef.set({fieldKey: fieldValue}, SetOptions(merge: true));

                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Tanggal ${fieldKey} berhasil disimpan sebagai "$fieldValue" untuk $user'),
                      ),
                    );

                    // Tutup dialog
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(content: Text('Gagal menyimpan field: $e')),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(content: Text('Gagal fetch dokumen: $e')),
    );
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
Widget _buildShiftIcon(String swapValue) {
  final parts = swapValue.split('_');
  final shift = parts.isNotEmpty ? parts[0] : '?';
  final status = parts.length > 1 ? parts[1] : '0';

  final isApproved = status == '1';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    height: 20,
    decoration: BoxDecoration(
      color: isApproved ? Colors.blue : Colors.grey,
      borderRadius: BorderRadius.circular(12),
      border: isApproved
          ? Border.all(color: Colors.white, width: 1.5)
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 🔢 ANGKA SHIFT (DIPASTIKAN MUNCUL)
      

   

        // 🔀 IKON SHUFFLE
        const Icon(
          Icons.swap_horiz,
          size: 11,
          color: Colors.white,
        ),     const SizedBox(width: 3),
          Text(
          shift,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11, // ⬅ diperbesar
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ],
    ),
  );
}
Future<void> fetchSwapEvents({
  required String user,
  required int year,
  required int month,
}) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('swap')
        .doc(year.toString())
        .collection(month.toString()) // ⬅ bulan 1 digit jika < 10
        .doc(user)
        .get();

    if (!snapshot.exists) {
      swapEvents.clear();
      return;
    }

    final data = snapshot.data() ?? {};

    swapEvents.clear();

    data.forEach((key, value) {
      // key = tanggal (contoh "30")
      // value = "3_0" / "3_1"
      final day = int.tryParse(key);
      if (day == null) return;

      final date = DateTime(year, month, day);
      swapEvents[date] = value.toString();
    });

    debugPrint('SWAP EVENTS: $swapEvents');
  } catch (e) {
    debugPrint('Gagal fetch swap: $e');
    swapEvents.clear();
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
  final dateKey = DateTime(day.year, day.month, day.day);

// Ambil swap untuk hari ini
final swapValue = swapEvents[onlyDate(day)];  // HARUS begini
 // pastikan pakai onlyDate(day)
final hasSwapShift = swapValue != null;

String swapStatusLocal = '';
String swapShiftNumberLocal = '';

if (hasSwapShift) {
  final parts = swapValue!.split('_'); // misal "3_0" atau "3_1"
  swapShiftNumberLocal = parts[0];     // nomor shift
  swapStatusLocal = parts[1];          // status swap
}
debugPrint('swapEvents untuk ${onlyDate(day)} = ${swapEvents[onlyDate(day)]}');


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

 return SizedBox(
  width: 46,
  height: 46,
  child: Stack(
    clipBehavior: Clip.none, // ⬅ PENTING: biar boleh keluar
    children: [
      // === TANGGAL (TETAP DI TENGAH) ===
      Center(
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
                decoration: const BoxDecoration(
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
      ),

      // === IKON SHIFT (BENAR-BENAR DI LUAR) ===
      if (swapValue != null)
        Positioned(
          bottom: -5,
          right: 6.5,
          child: _buildShiftIcon(swapValue),
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

// Ambil data swap untuk hari ini
final swapValue = swapEvents[onlyDate(day)];
final hasSwapShift = swapValue != null;

String swapStatusLocal = '';
String swapShiftNumberLocal = '';

if (hasSwapShift) {
  final parts = swapValue!.split('_'); // ['3','0'] atau ['3','1']
  swapShiftNumberLocal = parts[0];     // nomor shift
  swapStatusLocal = parts[1];          // status swap: '0' = pending, '1' = approved
}

  // Tombol Ajukan Libur
  final canApplyLibur = 
      !isLiburApproved && 
      !isLiburPending && 
       !hasSwapShift &&        
      masuk == null && 
      pulang == null && 
      !telatForDay;

  // Tombol Tukar Shift
  final canSwapShift = 
      masuk == null &&
      pulang == null &&
      !telatForDay &&
      !isLiburApproved &&
      !isLiburPending;

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
                const SizedBox(height: 8),

                // Status bar: masuk, pulang, telat, libur
                if (masuk != null && !telatForDay)
                  _infoBar(
                    icon: Icons.login,
                    label: 'Anda masuk jam ${TimeOfDay.fromDateTime(masuk).format(context)}',
                    color: Colors.blue,
                  ),
                if (telatForDay)
                  _infoBar(
                    icon: Icons.access_time,
                    label: masuk != null
                        ? 'Telat masuk jam ${TimeOfDay.fromDateTime(masuk).format(context)}'
                        : 'Anda telat',
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
                      Navigator.of(context, rootNavigator: true).pop();
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
                      Navigator.of(context, rootNavigator: true).pop();
                      await _batalkanPengajuan(day);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Batalkan pengajuan Libur',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                const SizedBox(height: 8),

if (hasSwapShift && swapStatusLocal == '0')
  ElevatedButton(
    onPressed: () async {
      if (localName != null) {
        await _cancelSwapShift(context, localName!, day);
        await fetchSwapEvents(
          user: localName!,
          year: day.year,
          month: day.month,
        );
        setState(() {});
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade600,
    ),
    child: const Text(
      'Batalkan Tukar Shift',
      style: TextStyle(color: Colors.white),
    ),
  )
else if (hasSwapShift && swapStatusLocal == '1')
  ElevatedButton.icon(
  onPressed: () {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shift sudah ditukar ke $swapShiftNumberLocal'),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.grey.shade300,   // bg abu-abu muda
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // tipis vertikal
    elevation: 0, // tanpa shadow
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20), // rounded tipis
    ),
  ),
  icon: const Icon(
    Icons.swap_horiz, 
    size: 16,       // icon kecil
    color: Colors.grey, 
  ),
  label: Text(
    'Ditukar ke shift $swapShiftNumberLocal',
    style: const TextStyle(
      color: Colors.black54, 
      fontSize: 13,    // lebih kecil
      fontWeight: FontWeight.w500,
    ),
  ),
),// Tombol untuk swap shift baru
if (!hasSwapShift && canSwapShift)
  ElevatedButton(
    onPressed: () {
      if (localName != null) {
        showSwapFieldDialog(context, localName!, day);
      }
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
      'Tukar Shift',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    ),
  ),



                const SizedBox(height: 12),

                // Tombol Tutup
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
