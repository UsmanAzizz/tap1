  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  enum AbsenButtonState { NA, MASUK, TELAT, PULANG }

  enum TimePhase {
    FREE,
    TENGGANG_MASUK,
    KERJA,
    TENGGANG_PULANG,
  }
  // Tambahkan di class AttendanceService
  // Map libur: key = DateTime (tahun, bulan, tanggal), value = '1' (approved) / '0' (pending)
 



  class AttendanceService {
    String status = 'Belum Absen';
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int permit = 0; // 0 = tidak ada izin, 1 = ada izin
    bool _isFetching = false;
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
String? _shiftHariIni;
 Map<String, String> liburMap = {};
String? get shiftHariIni => _shiftHariIni;

  // Fungsi untuk ambil status libur hari tertentu
  String _getLiburForDay(DateTime day) {
    final key = day.day.toString(); // ambil tanggal sebagai string
    return liburMap[key] ?? '';     // '' artinya bukan libur
  }

    // ===== JAM SHIFT =====
    DateTime? _masukMulai;
    DateTime? _masukAkhir;
    DateTime? _pulangMulai;
    DateTime? _pulangAkhir;

    Duration remainingTime = Duration.zero;
    Duration remainingTimeMasuk = Duration.zero;

    DateTime? get masukMulai => _masukMulai;
    DateTime? get masukAkhir => _masukAkhir;
    DateTime? get pulangMulai => _pulangMulai;
    DateTime? get pulangAkhir => _pulangAkhir;
  bool sudahMasukHariIni = false;
  bool sudahPulangHariIni = false;

    DateTime _combineWithToday(DateTime time) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, time.hour, time.minute, time.second);
    }

    // ==================== LOGIKA TOMBOL ====================
    // tetap ada getter lama untuk kompatibilitas HomePage
    bool get canAbsenMasuk {
      
      if (_masukMulai == null || _masukAkhir == null) return false;
      final now = DateTime.now();
      return now.isAfter(_masukMulai!) && now.isBefore(_masukAkhir!);
    }
  bool get isButtonDisabled {
    final now = DateTime.now();

    // libur
    if (permit == 1) return true;

    // sudah pulang → disable selamanya hari ini
    if (sudahPulangHariIni) return true;

    // sudah masuk / telat → disable sampai jam pulang
    if (sudahMasukHariIni) {
      if (_pulangMulai != null && now.isAfter(_pulangMulai!)) {
        return false; // buka lagi untuk pulang
      }
      return true; // masih kerja
    }

    return absenButtonState == AbsenButtonState.NA;
  }



  AbsenButtonState get absenButtonState {
    final now = DateTime.now();

    // shift belum di-set → tombol nonaktif
    if (_masukMulai == null || _masukAkhir == null || _pulangMulai == null || _pulangAkhir == null) {
      return AbsenButtonState.NA;
    }

    // ===== CEK LIBUR APPROVED =====
    final liburStatus = _getLiburForDay(now); // ambil status libur hari ini
    if (liburStatus == '1') {
      // Libur approved → tombol nonaktif
      return AbsenButtonState.NA;
    }

    // Tenggang absen masuk
    if (now.isAfter(_masukMulai!) && now.isBefore(_masukAkhir!)) return AbsenButtonState.MASUK;

    // Telat
    if (now.isAfter(_masukAkhir!) && now.isBefore(_pulangMulai!)) return AbsenButtonState.TELAT;

    // Absen pulang
    if (now.isAfter(_pulangMulai!) && now.isBefore(_pulangAkhir!)) return AbsenButtonState.PULANG;

    // Luar jam shift → tombol nonaktif
    return AbsenButtonState.NA;
  }





  String get buttonText {
    if (permit == 1) return 'ANDA SEDANG LIBUR';

    switch (absenButtonState) {
      case AbsenButtonState.MASUK:
        return 'MASUK';
      case AbsenButtonState.TELAT:
        return 'ABSEN TELAT';
      case AbsenButtonState.PULANG:
        return 'PULANG';
      case AbsenButtonState.NA:
      default:
        return '';
    }
  }


    String get phaseText {
    switch (currentPhase) {
      case TimePhase.TENGGANG_MASUK:
        return 'Tenggang waktu absen masuk';
      case TimePhase.KERJA:
        return 'Waktunya kerjaaa';
      case TimePhase.TENGGANG_PULANG:
        return 'Tenggang waktu absen pulang';
      case TimePhase.FREE:
      default:
        return 'Waktu bebas';
    }
  }

  Duration get phaseRemainingTime {
    final now = DateTime.now();

    switch (currentPhase) {
      case TimePhase.TENGGANG_MASUK:
        return _masukAkhir!.difference(now);

      case TimePhase.KERJA:
        return _pulangMulai!.difference(now);

      case TimePhase.TENGGANG_PULANG:
        return _pulangAkhir!.difference(now);

      default:
        return Duration.zero;
    }
  }

  TimePhase get currentPhase {
    final now = DateTime.now();

    if (_masukMulai == null ||
        _masukAkhir == null ||
        _pulangMulai == null ||
        _pulangAkhir == null) {
      return TimePhase.FREE;
    }

    // Sebelum jam masuk
    if (now.isBefore(_masukMulai!)) {
      return TimePhase.FREE;
    }

    // Tenggang absen masuk
    if (now.isAfter(_masukMulai!) && now.isBefore(_masukAkhir!)) {
      return TimePhase.TENGGANG_MASUK;
    }

    // WAKTU KERJA (WAJIB)
    if (now.isAfter(_masukAkhir!) && now.isBefore(_pulangMulai!)) {
      return TimePhase.KERJA;
    }

    // Tenggang absen pulang
    if (now.isAfter(_pulangMulai!) && now.isBefore(_pulangAkhir!)) {
      return TimePhase.TENGGANG_PULANG;
    }

    // Setelah jam pulang
    return TimePhase.FREE;
  }

Future<String?> getSwapShiftForUser(String user, DateTime day) async {
  try {
    final docRef = FirebaseFirestore.instance
        .collection('swap')
        .doc(day.year.toString())
        .collection(day.month.toString())
        .doc(user);

    final snapshot = await docRef.get();
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) return null;

    final fieldKey = day.day.toString(); // contoh "2"
    if (!data.containsKey(fieldKey)) return null;

    final value = data[fieldKey]?.toString(); // contoh "2_1" atau "2_0"

    print('[Swap] Field $fieldKey = $value');

    return value; // ⬅️ KEMBALIKAN APA ADANYA
  } catch (e) {
    print('Error load swap shift: $e');
    return null;
  }
}


// ==================== LOAD SHIFT HARI INI (PRIORITAS SWAP) ====================
Future<void> loadShiftHariIni(String userName) async {
  if (_isFetching) {
    print('[Attendance] ⛔ Masih fetching, dibatalkan');
    return;
  }

  _isFetching = true;

  try {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    print('===== LOAD SHIFT HARI INI =====');
    print('Tanggal: $today');

    // 1️⃣ PRIORITAS MUTLAK: SWAP
   final swapValue = await getSwapShiftForUser(userName, today);

if (swapValue != null && swapValue.contains('_')) {
  final parts = swapValue.split('_');
  final shift = parts[0]; // n
  final flag  = parts[1]; // 0 / 1

  print('[Attendance] 🔹 Swap ditemukan → value: $swapValue, shift: $shift, flag: $flag');

  if (flag == '1') {
    _shiftHariIni = shift;
    print('[Attendance] ✅ SWAP DIPAKAI → shift $_shiftHariIni');
  } else {
    _shiftHariIni = await _getLocalShift();
    print('[Attendance] ⚠ SWAP FLAG 0 → pakai shift lokal $_shiftHariIni');
  }
} else {
  _shiftHariIni = await _getLocalShift();
  print('[Attendance] ℹ️ Tidak ada swap → pakai shift lokal $_shiftHariIni');
}


    // 2️⃣ LOAD JAM SHIFT
    final profileDoc =
        await _firestore.collection('profile').doc('settings').get();
    final settings = profileDoc.data() ?? {};

    Timestamp? ts(String key) {
      for (final k in settings.keys) {
        if (k.toLowerCase() == key.toLowerCase()) {
          return settings[k] as Timestamp?;
        }
      }
      return null;
    }

    final masukA = ts('jam_masuk_${_shiftHariIni}A');
    final masukB = ts('jam_masuk_${_shiftHariIni}B');
    final pulangA = ts('jam_pulang_${_shiftHariIni}A');
    final pulangB = ts('jam_pulang_${_shiftHariIni}B');

    if ([masukA, masukB, pulangA, pulangB].contains(null)) {
      print('[Attendance] ❌ Jam shift TIDAK LENGKAP untuk shift $_shiftHariIni');
      return;
    }

    _masukMulai = _combineWithToday(masukA!.toDate());
    _masukAkhir = _combineWithToday(masukB!.toDate());
    _pulangMulai = _combineWithToday(pulangA!.toDate());
    _pulangAkhir = _combineWithToday(pulangB!.toDate());

    print('[Attendance] ✅ SHIFT $_shiftHariIni FINAL DIPAKAI');
  } catch (e) {
    print('[Attendance] ❌ ERROR load shift: $e');
  } finally {
    _isFetching = false;
    print('===== SELESAI LOAD SHIFT =====');
  }
}



  Future<void> loadLiburFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('permit').get();

      if (snapshot.docs.isEmpty) {
        print('Libur Map kosong');
        liburMap.clear();
        return;
      }

      liburMap.clear(); // reset dulu

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // misal field 'tanggal' berisi angka tanggal 1..31
        // dan field 'status' berisi '1' (approved) / '0' (pending)
        final tanggal = data['tanggal']?.toString();
        final status = data['status']?.toString() ?? '0';

        if (tanggal != null) {
          liburMap[tanggal] = status;
        }
      }

      print('=== DEBUG LIBUR ===');
      print('Libur Map: $liburMap');

      // cek status libur hari ini
      final todayStatus = _getLiburForDay(DateTime.now());
      print('Status libur hari ini (${DateTime.now().day}): $todayStatus');

    } catch (e) {
      print('Gagal load libur dari Firestore: $e');
      liburMap.clear();
    }
  }

  Future<void> loadPermitFromFirestore(String userName) async {
    try {
      final now = DateTime.now();
      final yearDoc = now.year.toString();
      final monthCol = now.month.toString(); // 1..12
      final dayField = now.day.toString();   // 1..31

      final docSnapshot = await FirebaseFirestore.instance
          .collection('permit')
          .doc(yearDoc)
          .collection(monthCol)
          .doc(userName)
          .get();

      if (!docSnapshot.exists) {
        permit = 0;
        print('Permit hari ini: $permit (doc tidak ada)');
        return;
      }

      final data = docSnapshot.data() ?? {};
      final value = data[dayField]?.toString() ?? '0';

      // 1 = ada izin, 0 = tidak ada izin
      permit = value == '1' ? 1 : 0;

      print('Permit hari ini: $permit');
    } catch (e) {
      permit = 0;
      print('Gagal load permit hari ini: $e');
    }
  }


    // ==================== FIRESTORE ====================
  Future<String> handleAbsenWithNotif(String userName) async {
    final now = DateTime.now();
    final buttonState = absenButtonState;

    if (buttonState == AbsenButtonState.NA) return 'Tombol sedang tidak aktif';

    final yearDoc = now.year.toString();
    final monthCol = now.month.toString(); // 1,2,3...
    final dayField = now.day.toString().padLeft(2, '0'); // 01,02,...

    final attendanceDocRef = _firestore
        .collection('attendance')
        .doc(yearDoc)
        .collection(monthCol)
        .doc(userName);

    final telatDocRef = _firestore
        .collection('telat')
        .doc(yearDoc)
        .collection(monthCol)
        .doc(userName);

    // field per tanggal
    final masukField = '${dayField}_masuk';
    final pulangField = '${dayField}_pulang';
    final telatField = '${dayField}_telat';

    // ambil data attendance dan telat
    final attendanceSnapshot = await attendanceDocRef.get();
    final attendanceData = attendanceSnapshot.data() ?? {};

    final telatSnapshot = await telatDocRef.get();
    final telatData = telatSnapshot.data() ?? {};

    // ===== MASUK =====
  // ===== MASUK =====
  if (buttonState == AbsenButtonState.MASUK) {
    // ❌ sudah masuk
    if (attendanceData.containsKey(masukField)) {
      sudahMasukHariIni = true;
      return 'Anda sudah absen masuk';
    }

    await attendanceDocRef.set(
      {masukField: now},
      SetOptions(merge: true),
    );

    // ✅ update state lokal
    sudahMasukHariIni = true;
    sudahPulangHariIni = false;

    status = 'Sudah Masuk';
    return 'Absen masuk berhasil';
  }


  // ===== TELAT =====
  if (buttonState == AbsenButtonState.TELAT) {
    // ❌ JIKA SUDAH MASUK → TIDAK BOLEH TELAT
    if (attendanceData.containsKey(masukField)) {
      sudahMasukHariIni = true;
      return 'Anda sudah absen masuk';
    }

    // ❌ JIKA SUDAH TELAT
    if (telatData.containsKey(telatField)) {
      sudahMasukHariIni = true;
      return 'Anda sudah absen telat';
    }

    // ✅ telat = tetap dianggap masuk
    await attendanceDocRef.set(
      {masukField: now},
      SetOptions(merge: true),
    );

    await telatDocRef.set(
      {telatField: '1'},
      SetOptions(merge: true),
    );

    // ✅ update state lokal
    sudahMasukHariIni = true;
    sudahPulangHariIni = false;

    status = 'Telat';
    return 'Absen telat berhasil';
  }


  // ===== PULANG =====
  if (buttonState == AbsenButtonState.PULANG) {
    // ❌ sudah pulang
    if (attendanceData.containsKey(pulangField)) {
      sudahPulangHariIni = true;
      return 'Anda sudah absen pulang';
    }

    await attendanceDocRef.set(
      {pulangField: now},
      SetOptions(merge: true),
    );

    // ⚠️ JANGAN tulis telat di sini
    // telat HANYA ditulis saat TELAT

    // ✅ update state lokal
    sudahPulangHariIni = true;

    status = 'Sudah Pulang';
    return 'Absen pulang berhasil';
  }



    return '⚠ Terjadi kesalahan';
  }


    // ==================== RESET HARIAN ====================
    Future<void> checkResetDaily() async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayString = '${now.year}-${now.month}-${now.day}';
      final lastClick = prefs.getString('LastClick') ?? '';

      if (lastClick != todayString) {
        status = 'Belum Absen';
        remainingTime = Duration.zero;
        remainingTimeMasuk = Duration.zero;
        await prefs.setString('LastClick', todayString);
      }
    }

    // ==================== LOAD SHIFT ====================
    Future<String> _getLocalShift() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('shift') ?? '1'; // default shift 1
    }

    // ==================== UTILS ====================
    String formatDuration(Duration d) {
      return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }

    // ==================== DEBUG PRINT ====================
  
  }
