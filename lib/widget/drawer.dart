import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

class AppDrawer extends StatefulWidget {
  final String userName;
  final VoidCallback onLogoutTap;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.onLogoutTap,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Map<String, dynamic>> ranking = [];
  Map<String, Timestamp> settingsData = {}; // ambil settings

  @override
  void initState() {
    super.initState();
    fetchSettingsAndRanking();
  }

  /// Ambil settings dari profile/settings
  Future<void> fetchSettingsAndRanking() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('profile')
          .doc('settings')
          .get();

      if (doc.exists) {
        settingsData = Map<String, Timestamp>.from(doc.data() ?? {});
        debugPrint('===== Settings Document =====');
        settingsData.forEach((key, value) {
          debugPrint('$key : $value');
        });
        debugPrint('=============================');
      }

      await fetchRanking();
    } catch (e) {
      debugPrint('Failed to fetch settings: $e');
    }
  }

  /// Ambil ranking berdasarkan shift dan jam masuk/pulang
  Future<void> fetchRanking() async {
    final ref = FirebaseFirestore.instance
        .collection('attendance')
        .doc('2026')
        .collection('1');

    final snapshot = await ref.get();
    List<Map<String, dynamic>> temp = [];

    for (var doc in snapshot.docs) {
      final userName = doc.id;
      final data = doc.data();

      // Tentukan shift yang paling sesuai untuk perhitungan ranking
      int? bestScore;

      settingsData.forEach((key, ts) {
        if (key.toLowerCase().contains('masuk')) {
          final shift = key.split('_')[1]; // misal Jam_masuk_1A → 1A
          final start = ts.toDate();
          final endKey = 'Jam_Pulang_$shift';
          if (settingsData.containsKey(endKey)) {
            final end = settingsData[endKey]!.toDate();

            for (var val in data.values) {
              if (val is Timestamp) {
                final dt = val.toDate();
                if (dt.isAfter(start) && dt.isBefore(end)) {
                  final duration = end.difference(dt).inMinutes.abs();
                  if (bestScore == null || duration < bestScore!) {
                    bestScore = duration;
                  }
                }
              }
            }
          }
        }
      });

      temp.add({
        'name': userName,
        'score': bestScore ?? 9999, // gunakan skor untuk sorting
      });
    }

    // Sorting berdasarkan score (semakin kecil semakin bagus)
    temp.sort((a, b) => a['score'].compareTo(b['score']));

    setState(() {
      ranking = temp.take(10).toList();
    });
  }

  Color _rankColor(int i) {
    if (i == 0) return const Color(0xFFF5B301);
    if (i == 1) return const Color(0xFF9E9E9E);
    if (i == 2) return const Color(0xFFB87333);
    return const Color(0xFF3F8EFC);
  }

  IconData _rankIcon(int i) => i < 3 ? Icons.emoji_events : Icons.circle;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF5F7FB),
      child: Column(
        children: [
          /// HEADER
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3F8EFC), Color(0xFF6FB1FF)],
              ),
            ),
            accountName: Text(
              widget.userName,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text('Gaya Group'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.userName.isNotEmpty ? widget.userName[0] : 'U',
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFF3F8EFC),
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.leaderboard_rounded,
                  size: 18,
                  color: Color(0xFF3F8EFC),
                ),
                SizedBox(width: 8),
                Text(
                  'Top 10 Kehadiran Bulan Ini',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),

          /// LIST
          Expanded(
            child: ranking.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: ranking.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = ranking[index];

                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(
                          vertical: -3,
                        ),
                        minLeadingWidth: 0,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: _rankColor(index).withOpacity(0.15),
                          child: Icon(
                            _rankIcon(index),
                            size: index < 3 ? 18 : 7,
                            color: _rankColor(index),
                          ),
                        ),
                        title: Text(
                          user['name'],
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),

          /// LOGOUT
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onLogoutTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.power_settings_new_rounded,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          )
        ],
      ),
    );
  }

  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyApp()),
    );
  }
}
