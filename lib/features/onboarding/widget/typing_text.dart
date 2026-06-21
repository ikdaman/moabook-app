// lib/features/onboarding/widget/typing_text.dart
import 'dart:async';
import 'package:flutter/material.dart';

class TypingText extends StatefulWidget {
  const TypingText({
    super.key,
    required this.phrases,
    this.style,
    this.textAlign = TextAlign.center,
    this.charInterval = const Duration(milliseconds: 60),
    this.eraseInterval = const Duration(milliseconds: 30),
    this.holdDuration = const Duration(milliseconds: 1000),
    this.eraseAtEnd = false,
    this.onComplete,
  });

  final List<String> phrases;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration charInterval;
  final Duration eraseInterval;
  final Duration holdDuration;
  final bool eraseAtEnd;
  final VoidCallback? onComplete;

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _text = '';
  bool _cursorOn = true;
  bool _cancelled = false;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (mounted) setState(() => _cursorOn = !_cursorOn);
      },
    );
    _run();
  }

  Future<void> _run() async {
    for (var p = 0; p < widget.phrases.length; p++) {
      final phrase = widget.phrases[p];
      // 전진 타이핑
      for (var i = 1; i <= phrase.length; i++) {
        if (!mounted || _cancelled) return;
        setState(() => _text = phrase.substring(0, i));
        await Future.delayed(widget.charInterval);
      }
      if (!mounted || _cancelled) return;
      await Future.delayed(widget.holdDuration);
      final isLast = p == widget.phrases.length - 1;
      if (!isLast || widget.eraseAtEnd) {
        // 백스페이스 삭제
        for (var i = phrase.length - 1; i >= 0; i--) {
          if (!mounted || _cancelled) return;
          setState(() => _text = phrase.substring(0, i));
          await Future.delayed(widget.eraseInterval);
        }
      }
    }
    if (!mounted || _cancelled) return;
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _cancelled = true;
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_text${_cursorOn ? '|' : ' '}',
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}
