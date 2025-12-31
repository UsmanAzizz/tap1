import 'package:flutter/material.dart';

void showTopNotification(
  BuildContext context, {
  required String message,
  bool success = true,
}) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  final topPadding = MediaQuery.of(context).padding.top;

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _AnimatedTopNotification(
      message: message,
      success: success,
      topPadding: topPadding,
      onClose: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _AnimatedTopNotification extends StatefulWidget {
  final String message;
  final bool success;
  final double topPadding;
  final VoidCallback onClose;

  const _AnimatedTopNotification({
    required this.message,
    required this.success,
    required this.topPadding,
    required this.onClose,
  });

  @override
  State<_AnimatedTopNotification> createState() =>
      _AnimatedTopNotificationState();
}

class _AnimatedTopNotificationState
    extends State<_AnimatedTopNotification> {
  bool visible = false;

  @override
  void initState() {
    super.initState();

    // Trigger animasi masuk
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => visible = true);
    });

    // Auto dismiss
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => visible = false);
        Future.delayed(
          const Duration(milliseconds: 300),
          widget.onClose,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      top: visible
          ? widget.topPadding + 16
          : widget.topPadding - 150, // slide dari atas
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: visible ? 1 : 0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.success
                    ? [Colors.green.shade600, Colors.green.shade400]
                    : [Colors.redAccent.shade700, Colors.redAccent.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.3,
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
