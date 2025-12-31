import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pages/HomePage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  bool isLogin = false;
  bool isInitializing = true;
  final TextEditingController userIdController = TextEditingController();
  String? errorText;

  Map<String, dynamic> firestoreData = {};
  bool isLoading = true;

  late AnimationController fadeController;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();

    fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: fadeController, curve: Curves.easeIn),
    );

    checkLoginStatus();
    fetchFirestoreData();
  }

  @override
  void dispose() {
    fadeController.dispose();
    super.dispose();
  }

  Future<void> checkLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id');

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      if (userId != null) {
        setState(() {
          isLogin = true;
        });
      }

      setState(() => isInitializing = false);
      fadeController.forward();
      debugPrint('✅ User already logged in: $userId');
    } catch (e) {
      debugPrint('⚠️ SharedPreferences error: $e');
      setState(() {
        isInitializing = false;
      });
      fadeController.forward();
    }
  }

  Future<void> fetchFirestoreData() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('profile').get();
      Map<String, dynamic> tempData = {};
      for (var doc in snapshot.docs) {
        tempData[doc.id] = doc.data();
      }

      if (!mounted) return;

      setState(() {
        firestoreData = tempData;
        isLoading = false;
      });
      debugPrint('✅ Profile collection fetched: $firestoreData');

      final prefs = await SharedPreferences.getInstance();

      if (tempData['location'] != null) {
        final locMap = tempData['location'] as Map<String, dynamic>;
        Map<String, String> locStringMap = {};
        locMap.forEach((key, value) {
          final geo = value as GeoPoint;
          locStringMap[key] = '${geo.latitude},${geo.longitude}';
        });
        await prefs.setString('profile_location', locStringMap.toString());
      }

      if (tempData['settings'] != null) {
        final settingsMap = tempData['settings'] as Map<String, dynamic>;
        Map<String, int> settingsMillis = {};
        settingsMap.forEach((key, value) {
          final ts = value as Timestamp;
          settingsMillis[key] = ts.millisecondsSinceEpoch;
        });
        await prefs.setString('profile_settings', settingsMillis.toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        firestoreData = {'error': 'Gagal mengambil data'};
        isLoading = false;
      });
      debugPrint('❌ Firestore fetch failed: $e');
    }
  }

  Future<void> login() async {
  final userId = userIdController.text.trim();

  if (userId.isEmpty) {
    setState(() => errorText = 'User ID wajib diisi');
    return;
  }
  if (!RegExp(r'^\d+$').hasMatch(userId)) {
    setState(() => errorText = 'User ID harus berupa angka');
    return;
  }

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('id', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        errorText = 'User ID tidak ditemukan';
      });
      return;
    }

    final doc = snapshot.docs.first;
    final userName = doc.id;

    // Ambil field shift, jika tidak ada default ke ''
    final shift = doc.data()['shift']?.toString() ?? '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('nama', userName);
    await prefs.setString('shift', shift); // simpan shift

    if (!mounted) return;

    await fadeController.reverse();
    setState(() {
      isLogin = true;
      errorText = null;
    });
    await fadeController.forward();

    debugPrint('✅ Login berhasil: user_id=$userId, nama=$userName, shift=$shift');
  } catch (e) {
    debugPrint('❌ Login gagal: $e');
    setState(() => errorText = 'Terjadi kesalahan saat login');
  }
}


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: Colors.white, // background putih
      ),
      home:Container(
  color: Colors.white, // pastikan background putih
  child: AnimatedBuilder(
        animation: fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: fadeAnimation.value,
            child: isInitializing
                ? const Scaffold(
                    backgroundColor: Colors.white,
                    body: Center(
                      child: Text(
                        'Menginisialisasi...',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  )
                : isLogin
                    ? const HomePage()
                    : loginPage(),
          );
        },
      ),
      )  );
  }

  Widget loginPage() {
    return Scaffold(
      backgroundColor: Colors.white, // background putih
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    children: [
                      const TextSpan(text: 'Molecule'),
                      TextSpan(
                        text: '.io',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: userIdController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'User ID',
                    labelStyle: TextStyle(
                        color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    prefixIcon:
                        Icon(Icons.person_outline, color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: login,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
