import 'dart:math';
import 'package:flutter/material.dart';

class HeaderWithSymbols extends StatelessWidget {
  final String name;
  final VoidCallback onDrawerTap;
  const HeaderWithSymbols({super.key, required this.name, required this.onDrawerTap});

  @override
  Widget build(BuildContext context) {
    final random = Random();

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

        // Teks di kiri bawah + simbol acak
        Positioned(
          left: 20,
          bottom: 30,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ...List.generate(15, (index) {
                final symbols = ['X', 'O', '▢', '△'];
                final symbol = symbols[random.nextInt(symbols.length)];
                final leftOffset = random.nextDouble() * 50;
                final topOffset = random.nextDouble() * 120;
                final opacity = 0.05 + random.nextDouble() * 0.15;
                final fontSize = 10 + random.nextInt(6);

                return Positioned(
                  left: leftOffset,
                  top: topOffset,
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: Colors.white.withOpacity(opacity),
                      fontSize: fontSize.toDouble(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
            ],
          ),
        ),

        // Drawer icon
        Positioned(
          bottom: 40,
          right: 16,
          child: GestureDetector(
            onTap: onDrawerTap,
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
