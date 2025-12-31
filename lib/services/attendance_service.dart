import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AbsenButtonState { NA, MASUK, PULANG }
enum TimePhase {
  FREE,
  TENGGANG_MASUK,
  KERJA,
  TENGGANG_PULANG,
}

class AttendanceService {
  String status = 'Belum Absen';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isFetching = false;

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

  bool get isButtonDisabled => absenButtonState == AbsenButtonState.NA;

  AbsenButtonState get absenButtonState {
    final now = DateTime.now();

    if (_masukMulai == null || _masukAkhir == null || _pulangMulai == null || _pulangAkhir == null) {
      return AbsenButtonState.NA;
    }

    if (now.isAfter(_masukMulai!) && now.isBefore(_masukAkhir!)) return AbsenButtonState.MASUK;
    if (now.isAfter(_pulangMulai!) && now.isBefore(_pulangAkhir!)) return AbsenButtonState.PULANG;

    return AbsenButtonState.NA;
  }

  String get buttonText {
    switch (absenButtonState) {
      case AbsenButtonState.MASUK:
        return 'MASUK';
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
      return 'Sedang waktu kerja';
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


  // ==================== FIRESTORE ====================
  Future<String> handleAbsenWithNotif(String userName) async {
    final now = DateTime.now();
    final buttonState = absenButtonState;

    if (buttonState == AbsenButtonState.NA) return 'Tombol sedang tidak aktif';

    final yearDoc = now.year.toString();
    final monthCol = now.month.toString().padLeft(2, '0');
    final dayField = now.day.toString().padLeft(2, '0');
    final userDocRef = _firestore.collection('attendance').doc(yearDoc).collection(monthCol).doc(userName);

    final snapshot = await userDocRef.get();
    final data = snapshot.data() ?? {};
    final todayValue = data[dayField];

    if (buttonState == AbsenButtonState.MASUK) {
      if (todayValue == 0) return 'Anda sudah absen masuk';
      await userDocRef.set({dayField: 0}, SetOptions(merge: true));
      status = 'Sudah Masuk';
      return '✅ Absen masuk berhasil';
    }

    if (buttonState == AbsenButtonState.PULANG) {
      if (todayValue == 1) return 'Anda sudah absen pulang';
      await userDocRef.set({dayField: 1}, SetOptions(merge: true));
      status = 'Sudah Pulang';
      return '✅ Absen pulang berhasil';
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

  Future<void> loadShiftTimesFromLocal() async {
    try {
      _isFetching = true;

      final shiftNumber = await _getLocalShift();

      final profileDoc = await _firestore.collection('profile').doc('settings').get();
      final settings = profileDoc.data() ?? {};

      Timestamp? getTimestamp(String key) {
        for (var k in settings.keys) {
          if (k.toLowerCase() == key.toLowerCase()) return settings[k] as Timestamp?;
        }
        return null;
      }

      final masukA = getTimestamp('jam_masuk_${shiftNumber}A');
      final masukB = getTimestamp('jam_masuk_${shiftNumber}B');
      final pulangA = getTimestamp('jam_pulang_${shiftNumber}A');
      final pulangB = getTimestamp('jam_pulang_${shiftNumber}B');

      if (masukA != null && masukB != null && pulangA != null && pulangB != null) {
        _masukMulai = _combineWithToday(masukA.toDate());
        _masukAkhir = _combineWithToday(masukB.toDate());
        _pulangMulai = _combineWithToday(pulangA.toDate());
        _pulangAkhir = _combineWithToday(pulangB.toDate());
      } else {
        _masukMulai = null;
        _masukAkhir = null;
        _pulangMulai = null;
        _pulangAkhir = null;
      }

      _isFetching = false;
      print('[Attendance] Shift $shiftNumber loaded successfully.');
    } catch (e) {
      _isFetching = false;
      _masukMulai = null;
      _masukAkhir = null;
      _pulangMulai = null;
      _pulangAkhir = null;
      remainingTime = Duration.zero;
      remainingTimeMasuk = Duration.zero;
      print('[Attendance] Failed to load shift times: $e');
    }
  }

  // ==================== UTILS ====================
  String formatDuration(Duration d) {
    return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  // ==================== DEBUG PRINT ====================
 
}
