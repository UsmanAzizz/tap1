// bubble_widget.dart
import 'dart:math';
import 'package:flutter/material.dart';

class Bubble {
  double x, y, size, speed, dx, opacity;
  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.dx,
    required this.opacity,
  });
}

class BubbleWidget extends StatefulWidget {
  const BubbleWidget({super.key});

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  final int bubbleCount = 20;
  final List<Bubble> bubbles = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < bubbleCount; i++) {
      bubbles.add(_createBubble());
    }
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1000))
      ..addListener(_updateBubbles)
      ..repeat();
  }

  Bubble _createBubble() {
    double size = 15 + _random.nextDouble() * 25;
    return Bubble(
      x: _random.nextDouble(),
      y: 1.0 + _random.nextDouble(),
      size: size,
      speed: 0.0008 + _random.nextDouble() * 0.0015,
      dx: (_random.nextDouble() - 0.5) * 0.003,
      opacity: 0.3 + _random.nextDouble() * 0.5,
    );
  }

  void _updateBubbles() {
    setState(() {
      for (var b in bubbles) {
        b.y -= b.speed;
        b.x += b.dx;
        if (b.y < -0.1 || b.x < -0.1 || b.x > 1.1) {
          var newB = _createBubble();
          b.y = newB.y;
          b.x = newB.x;
          b.size = newB.size;
          b.speed = newB.speed;
          b.dx = newB.dx;
          b.opacity = newB.opacity;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: bubbles.map((b) {
          return Positioned(
            left: b.x * constraints.maxWidth,
            top: b.y * constraints.maxHeight,
            child: Opacity(
              opacity: b.opacity,
              child: Container(
                width: b.size,
                height: b.size,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}
