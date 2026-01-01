import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class AppDrawer extends StatelessWidget {
  final String userName;
  final VoidCallback onLogoutTap;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.onLogoutTap, // callback logout dari HomePage
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName, style: const TextStyle(fontSize: 18)),
            accountEmail: null,
            currentAccountPicture: CircleAvatar(
              child: Text(userName.isNotEmpty ? userName[0] : 'U'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: onLogoutTap, // jalankan callback
          ),
        ],
      ),
    );
  }

  /// opsional: bisa juga bikin fungsi logout internal,
  /// tapi harus dikirim context dari HomePage untuk Navigator
  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('nama');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyApp()),
    );
  }
}
