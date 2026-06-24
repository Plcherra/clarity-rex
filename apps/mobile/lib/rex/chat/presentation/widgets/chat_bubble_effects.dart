import 'package:flutter/material.dart';

import 'package:clarity/widgets/clarity_path_loader.dart';

class ChatTypingDots extends StatelessWidget {
  const ChatTypingDots({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: ClarityInlineLoader(size: 22, strokeWidth: 2),
    );
  }
}

class ChatStreamingCursor extends StatefulWidget {
  const ChatStreamingCursor({super.key, required this.color});

  final Color color;

  @override
  State<ChatStreamingCursor> createState() => _ChatStreamingCursorState();
}

class _ChatStreamingCursorState extends State<ChatStreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_controller),
      child: Container(
        width: 3,
        height: 18,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class ChatBubbleTailPainter extends CustomPainter {
  const ChatBubbleTailPainter({required this.color, required this.isUser});

  final Color color;
  final bool isUser;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isUser) {
      path
        ..moveTo(size.width - 1, size.height - 12)
        ..lineTo(size.width + 7, size.height - 5)
        ..lineTo(size.width - 1, size.height - 2);
    } else {
      path
        ..moveTo(1, size.height - 12)
        ..lineTo(-7, size.height - 5)
        ..lineTo(1, size.height - 2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ChatBubbleTailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isUser != isUser;
  }
}
