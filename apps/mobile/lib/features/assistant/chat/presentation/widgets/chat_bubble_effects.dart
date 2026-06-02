import 'package:flutter/material.dart';

class ChatTypingDots extends StatefulWidget {
  const ChatTypingDots({super.key, required this.color});

  final Color color;

  @override
  State<ChatTypingDots> createState() => _ChatTypingDotsState();
}

class _ChatTypingDotsState extends State<ChatTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value + (index * 0.22)) % 1;
            final opacity = phase < 0.5 ? 0.35 + phase : 1.35 - phase;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: opacity.clamp(0.35, 1)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
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
