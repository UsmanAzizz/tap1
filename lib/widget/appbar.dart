import 'dart:math';
import 'package:flutter/material.dart';

class HeaderWithSymbols extends StatefulWidget {
  final String name;
  final VoidCallback onDrawerTap;
  final String currentShift;

  const HeaderWithSymbols({
    super.key,
    required this.name,
    required this.onDrawerTap,
    required this.currentShift,
    required String docName,
  });

  @override
  State<HeaderWithSymbols> createState() => _HeaderWithSymbolsState();
}

class _HeaderWithSymbolsState extends State<HeaderWithSymbols>
    with TickerProviderStateMixin {
  final Random _random = Random();

  // Clouds
  final int numClouds = 5;
  late List<double> cloudSizes;
  late List<double> cloudTopPositions;
  late List<double> cloudOpacities;

  // Stars
  final int numStars = 20;
  late List<Offset> starPositions;
  late List<double> starSizes;
  late List<double> starOpacities;
  late List<bool> starVisible;

  // Pesawat / burung
  bool showPlane = false;
  late double planeTop;
  late double planeLeft;

  // Controllers
  late AnimationController _cloudController;
  late AnimationController _planeController;

  @override
  void initState() {
    super.initState();

    // Clouds
    cloudSizes = List.generate(numClouds, (_) => _random.nextDouble() * 30 + 20);
    cloudTopPositions = List.generate(numClouds, (_) => _random.nextDouble() * 60 + 10);
    cloudOpacities = List.generate(numClouds, (_) => _random.nextDouble() * 0.3 + 0.5);

    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 100), // lambat seperti awan
    )..repeat();

    // Stars
    starPositions = List.generate(numStars, (_) => Offset(_random.nextDouble(), _random.nextDouble()));
    starSizes = List.generate(numStars, (_) => _random.nextDouble() * 5 + 1);
    starOpacities = List.generate(numStars, (_) => 0.0);
    starVisible = List.generate(numStars, (_) => false);

    _startStarLoop();

    // Plane controller
    _planeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 100), // sama dengan awan
    )..repeat();

    // Set plane initial position
    _resetPlane();
  }

  void _startStarLoop() {
    for (int i = 0; i < numStars; i++) {
      _scheduleStar(i);
    }
  }

  void _scheduleStar(int index) async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(4500)));
      if (!mounted) return;

      setState(() {
        starVisible[index] = true;
        starPositions[index] = Offset(_random.nextDouble(), _random.nextDouble());
        starOpacities[index] = _random.nextDouble() * 0.5 + 0.5;
      });

      await Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(2000)));
      if (!mounted) return;

      setState(() {
        starVisible[index] = false;
      });
    }
  }

  void _resetPlane() {
    planeTop = 20.0 + _random.nextDouble() * 50; // acak tinggi
    planeLeft = 1.0; // mulai dari kanan (0 = kiri, 1 = kanan)
    showPlane = true;
  }

  @override
  void dispose() {
    _cloudController.dispose();
    _planeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerHeight = 130.0;

    final bool isNight = DateTime.now().hour >= 18;

    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(28)),
      child: Container(
        height: containerHeight,
        decoration: BoxDecoration(
          gradient: isNight
              ? const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 6, 48, 82),
                    Color.fromARGB(255, 6, 48, 82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 49, 158, 248),
                    Color.fromARGB(255, 59, 131, 220),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Stack(
          children: [
            // Clouds
            ...List.generate(numClouds, (i) {
              return AnimatedBuilder(
                animation: _cloudController,
                builder: (context, child) {
                  double progress = (_cloudController.value + i * 0.2) % 1;
                  double x = -cloudSizes[i] + progress * (screenWidth + cloudSizes[i]);
                  return Positioned(
                    top: cloudTopPositions[i],
                    left: x,
                    child: Opacity(
                      opacity: cloudOpacities[i],
                      child: Icon(
                        Icons.cloud,
                        size: cloudSizes[i],
                        color: Colors.white.withOpacity(isNight ? 0.5 : 0.8),
                      ),
                    ),
                  );
                },
              );
            }),

            // Plane / burung (siang)
          // Plane / burung (siang)



            // Stars malam hari
            if (isNight)
              ...List.generate(numStars, (i) {
                return Positioned(
                  left: starPositions[i].dx * screenWidth,
                  top: starPositions[i].dy * containerHeight,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: starVisible[i] ? starOpacities[i] : 0.0,
                    child: Container(
                      width: starSizes[i],
                      height: starSizes[i],
                      decoration: const BoxDecoration(
                        color: Colors.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),

            // Nama, Gaya Group, Shift
            Positioned(
              left: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Gaya Group',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Shift ${widget.currentShift.isNotEmpty ? widget.currentShift : "-"}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Icon sun / moon
            Positioned(
              bottom: 32,
              right: 18,
              child: GestureDetector(
                onTap: widget.onDrawerTap,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isNight ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                    color: Colors.yellow,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
