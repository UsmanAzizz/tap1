import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HeaderWithSymbols extends StatefulWidget {
  final String name;
  final VoidCallback onDrawerTap;
  final String docName; // Nama dokumen yang ingin diambil

  const HeaderWithSymbols({
    super.key,
    required this.name,
    required this.onDrawerTap,
    required this.docName,
  });

  @override
  State<HeaderWithSymbols> createState() => _HeaderWithSymbolsState();
}

class _HeaderWithSymbolsState extends State<HeaderWithSymbols> {
 @override
  void initState() {
    super.initState();
    fetchAttendance2026Month1();
  }

  /// Ambil semua dokumen dan field di attendance/2026/1
  Future<void> fetchAttendance2026Month1() async {
    final collectionRef = FirebaseFirestore.instance.collection('attendance');

    // Dokumen tahun 2026
    final yearDocRef = collectionRef.doc('2026');

    // Subcollection bulan 1
    final monthColRef = yearDocRef.collection('1');

    final snapshot = await monthColRef.get();

    if (snapshot.docs.isEmpty) {
      print('attendance/2026/1 → (no docs)');
      return;
    }

    for (var doc in snapshot.docs) {
      await traverseDoc(doc.reference, prefix: 'attendance/2026/1');
    }
  }

  /// Traversal dokumen dan subcollection (rekursif)
 Future<void> traverseDoc(DocumentReference docRef,
    {required String prefix}) async {
  try {
    final docSnap = await docRef.get();
    final data = docSnap.data() as Map<String, dynamic>?;

    // 1️⃣ Print field dokumen utama dulu
    if (data == null || data.isEmpty) {
      print('$prefix/${docRef.id} → (no fields)');
    } else {
      data.forEach((key, value) {
        print('$prefix/${docRef.id}/$key → $value');
      });
    }

    // 2️⃣ Loop subcollection jika ada
    final knownSubCollections = ['shift', 'details'];
    for (var subCol in knownSubCollections) {
      final subColRef = docRef.collection(subCol);
      final subSnapshot = await subColRef.get();

      if (subSnapshot.docs.isEmpty) {
        print('$prefix/${docRef.id}/$subCol → (no docs)');
      } else {
        for (var subDoc in subSnapshot.docs) {
          await traverseDoc(subDoc.reference,
              prefix: '$prefix/${docRef.id}/$subCol');
        }
      }
    }
  } catch (e) {
    print('Error fetching $prefix: $e');
  }
}



  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color.fromARGB(255, 49, 158, 248), Color.fromARGB(255, 59, 131, 220)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 0,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        // Floating shapes
        Positioned(
          top: 50,
          right: 40,
          child: CircleAvatar(radius: 12, backgroundColor: Colors.white.withOpacity(0.1)),
        ),
        Positioned(
          top: 70,
          right: 50,
          child: CircleAvatar(radius: 6, backgroundColor: Colors.yellow.withOpacity(0.1)),
        ),
        // Teks di kiri bawah
        Positioned(
          left: 20,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 0),
              const Text(
                'Gaya Group',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Drawer icon
        Positioned(
          bottom: 40,
          right: 16,
          child: GestureDetector(
            onTap: widget.onDrawerTap,
            child: const Icon(
              Icons.wb_sunny,
              color: Colors.yellowAccent,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}
