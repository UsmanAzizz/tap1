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

  @override
  void initState() {
    super.initState();
    fetchRanking();
  }

  Future<void> fetchRanking() async {
    final ref = FirebaseFirestore.instance
        .collection('attendance')
        .doc('2026')
        .collection('1');

    final snapshot = await ref.get();
    List<Map<String, dynamic>> temp = [];

    for (var doc in snapshot.docs) {
      DateTime? earliest;
      DateTime? latest;

      doc.data().forEach((_, value) {
        if (value is Timestamp) {
          final dt = value.toDate();
          earliest = earliest == null || dt.isBefore(earliest!) ? dt : earliest;
          latest = latest == null || dt.isAfter(latest!) ? dt : latest;
        }
      });

      if (earliest != null && latest != null) {
        final duration = latest!.difference(earliest!).inMinutes;
        final score = (480 - duration).abs();

        temp.add({'name': doc.id, 'score': score});
      }
    }

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

  IconData _rankIcon(int i) =>
      i < 3 ? Icons.emoji_events : Icons.circle;

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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
  children: const [
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
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = ranking[index];

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  _rankColor(index).withOpacity(0.18),
                              child: Icon(
                                _rankIcon(index),
                                size: index < 3 ? 20 : 8,
                                color: _rankColor(index),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                user['name'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
