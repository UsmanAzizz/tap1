import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceCalendar extends StatefulWidget {
  const AttendanceCalendar({super.key});

  @override
  State<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends State<AttendanceCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  Map<DateTime, String> firebaseEvents = {};
  String? localName;

  @override
  void initState() {
    super.initState();
    _loadLocalNameAndAttendance();
  }

  Future<void> _loadLocalNameAndAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('nama') ?? '';
    if (!mounted) return;

    setState(() {
      localName = name;
    });

    if (name.isNotEmpty) {
      await loadAttendanceFromFirebase(name);
    }
  }

  Future<void> loadAttendanceFromFirebase(String name) async {
    try {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString();

      final yearDoc = FirebaseFirestore.instance.collection('attendance').doc(year);
      final monthColSnapshot = await yearDoc.collection(month).get();
      if (monthColSnapshot.docs.isEmpty) return;

      final userDoc = monthColSnapshot.docs.firstWhere(
        (doc) => doc.id == name,
        orElse: () => throw 'Dokumen user "$name" tidak ditemukan',
      );

      final userData = userDoc.data();

      Map<DateTime, String> temp = {};
      userData.forEach((key, value) {
        final day = int.tryParse(key) ?? 0;
        if (day > 0) {
          final date = DateTime(now.year, now.month, day);
          temp[date] = value.toString();
        }
      });

      if (!mounted) return;
      setState(() {
        firebaseEvents = temp;
      });
    } catch (e) {
      debugPrint('Gagal load data absen: $e');
    }
  }

  List<String> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    if (!firebaseEvents.containsKey(key)) return [];
    return [firebaseEvents[key]!];
  }

  Widget _buildDayCell(DateTime day) {
  final eventsForDay = _getEventsForDay(day);
  Color? bgColor;

  if (eventsForDay.contains('1')) {
    bgColor = const Color.fromARGB(255, 84, 218, 89); // sudah absen
  } else if (eventsForDay.contains('0')) {
    bgColor = Colors.blue; // belum absen
  }

  return Container(
    margin: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: bgColor ?? Colors.transparent,
      shape: BoxShape.circle, // lingkaran
    ),
    alignment: Alignment.center,
    child: Text(
      '${day.day}',
      style: TextStyle(
        color: bgColor != null ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}


  void _showAttendanceDialog(DateTime day) {
  final eventsForDay = _getEventsForDay(day);
  final statusText = eventsForDay.isEmpty
      ? 'Belum ada data'
      : eventsForDay.first == '1'
          ? 'Sudah absen'
          : 'Belum absen';

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tanggal: ${day.day}-${day.month}-${day.year}',
                  style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  'Status: $statusText',
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 20),
                if (eventsForDay.isEmpty)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Libur berhasil diajukan!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    child: const Text(
                      'Ajukan Libur',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(color: Colors.blue),
                  ),
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
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2023, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: focusedDay,
      calendarFormat: _calendarFormat,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      onPageChanged: (focused) => setState(() => focusedDay = focused),
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
    );
  }
}
