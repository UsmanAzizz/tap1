import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: BubbleWidget(),
    ),
  ));
}

class BubbleWidget extends StatefulWidget {
  const BubbleWidget({super.key});

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  // Awan
  final int cloudCount = 8;
  late List<_Cloud> clouds;

  // Pohon beriringan
  final int treeCount = 10;
  late List<_MovingTree> trees;

  @override
  void initState() {
    super.initState();

    // Inisialisasi awan
    clouds = List.generate(cloudCount, (_) => _createCloud());

    // Inisialisasi pohon beriringan
   trees = List.generate(treeCount, (i) {
  return _MovingTree(
    x: i / treeCount,
    height: 20 + _random.nextInt(25), // 20–39 px → lebih kecil
    speed: 0.00005 + _random.nextDouble() * 0.00005, // sangat lambat
  );
});

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() {
        setState(() {
          // Update awan
          for (var cloud in clouds) {
            cloud.x += cloud.speed;
            if (cloud.x > 1.2) {
              cloud.x = -0.3;
              cloud.y = _random.nextDouble() * 0.6 + 0.2;
              cloud.size = 60 + _random.nextDouble() * 120;
              cloud.opacity = 0.2 + _random.nextDouble() * 0.3;
            }
          }

          // Update pohon (bergerak sangat lambat ke kiri)
         for (var tree in trees) {
  tree.x -= tree.speed;
  if (tree.x < -0.5) {
    tree.x = 1.0 + _random.nextDouble();
    tree.height = 25 + _random.nextInt(5); // 20–39 px → tetap kecil
  }
}

        });
      });

    _controller.repeat();
  }

  // Fungsi buat awan
  _Cloud _createCloud() {
    return _Cloud(
      x: _random.nextDouble(),
      y: _random.nextDouble() * 0.6 + 0.2,
      size: 60 + _random.nextDouble() * 120,
      speed: 0.0002 + _random.nextDouble() * 0.0005, // awan lebih lambat
      opacity: 0.2 + _random.nextDouble() * 0.3,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final bottomHeight = constraints.maxHeight * 0.3; // 30% bawah layar
      final treeOffset = 130.0; // naik agar terlihat di atas konten parent

      return Stack(
        children: [
          // Pohon beriringan di bagian bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: bottomHeight + treeOffset,
            child: Stack(
              children: trees.map((tree) {
                return Positioned(
                  left: tree.x * constraints.maxWidth,
                  bottom: treeOffset,
                  child: Icon(
                    Icons.grass,
                    color: Colors.green.withOpacity(0.8),
                    size: tree.height.toDouble(),
                  ),
                );
              }).toList(),
            ),
          ),
          // Awan bergerak di atas
          ...clouds.map((cloud) {
            return Positioned(
              left: cloud.x * constraints.maxWidth,
              top: cloud.y * constraints.maxHeight,
              child: Opacity(
                opacity: cloud.opacity.clamp(0, 1),
                child: Icon(
                  Icons.cloud,
                  size: cloud.size,
                  color: Colors.lightBlueAccent.withOpacity(cloud.opacity),
                ),
              ),
            );
          }).toList(),
        ],
      );
    });
  }
}

// Class untuk awan
class _Cloud {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  _Cloud({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Class untuk pohon bergerak (sangat lambat)
class _MovingTree {
  double x; // posisi horizontal 0..1
  int height; // ukuran pohon
  double speed; // sangat lambat

  _MovingTree({
    required this.x,
    required this.height,
    required this.speed,
  });
}
